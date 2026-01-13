#!/bin/sh
# AWK Indirect Call Processor - TWO PASS VERSION

set -e

INPUT_FILE="$1"
OUTPUT_FILE="${2:-}"
DAP_TPL_DIR="${3:-$(dirname "$INPUT_FILE")}"

[ ! -f "$INPUT_FILE" ] && echo "Error: File not found: $INPUT_FILE" >&2 && exit 1

TMP_FILE=$(mktemp)
TMP_REGISTERED=$(mktemp)
TMP_ALL_FUNCS=$(mktemp)
TMP_SIGS=$(mktemp)
trap 'rm -f "$TMP_FILE" "$TMP_REGISTERED" "$TMP_ALL_FUNCS" "$TMP_SIGS"' EXIT

# PASS 1: Extract registered function names
# Scan for register_* calls in constructs
find "$DAP_TPL_DIR/constructs" -name "*.awk" -exec grep -h "register_" {} \; 2>/dev/null | \
awk -F'"' '{
    if ($0 ~ /register_opening_pattern/) {
        if (NF >= 6) print $6
    } else {
        if (NF >= 4) print $4
    }
}' > "$TMP_REGISTERED"

# Scan for VAR_FUNC_DISPATCH registrations in core
find "$DAP_TPL_DIR/core" -name "*.awk" -exec grep -h "VAR_FUNC_DISPATCH\[" {} \; 2>/dev/null | \
awk -F'"' '{
    # Extract function name from VAR_FUNC_DISPATCH["name"] = "function_name"
    if (NF >= 4) print $4
}' >> "$TMP_REGISTERED"

# Remove duplicates
sort -u "$TMP_REGISTERED" > "$TMP_REGISTERED.tmp"
mv "$TMP_REGISTERED.tmp" "$TMP_REGISTERED"

echo "# Found $(wc -l < "$TMP_REGISTERED") registered functions" >&2

# PASS 2: Extract ALL function definitions
find "$DAP_TPL_DIR/constructs" "$DAP_TPL_DIR/core" -name "*.awk" -exec grep "^function " {} \; 2>/dev/null | \
awk '{
    line = $0
    sub(/^function[ \t]+/, "", line)
    fname = line
    sub(/\(.*/, "", fname)
    
    params = line
    sub(/^[^(]*\(/, "", params)
    sub(/\).*/, "", params)
    sub(/,[ \t][ \t]+.*/, "", params)
    sub(/,[ \t]*,.*/, "", params)
    
    gsub(/[ \t]/, "", params)
    if (params == "") {
        print fname "|0"
    } else {
        print fname "|" split(params, arr, ",")
    }
}' > "$TMP_ALL_FUNCS"

# PASS 3: Filter only registered functions
awk -F'|' 'FNR==NR {reg[$1]=1; next} $1 in reg {print}' "$TMP_REGISTERED" "$TMP_ALL_FUNCS" | sort -u > "$TMP_SIGS"

echo "# Generated signatures for $(wc -l < "$TMP_SIGS") functions" >&2

# Replace @func() calls
awk '{
    line = $0
    while (match(line, /@[a-zA-Z_][a-zA-Z0-9_]*\([^)]*\)/)) {
        before = substr(line, 1, RSTART - 1)
        call = substr(line, RSTART, RLENGTH)
        after = substr(line, RSTART + RLENGTH)
        
        func_var = substr(call, 2, index(call, "(") - 2)
        args_start = index(call, "(") + 1
        args_end = index(call, ")") - args_start
        args = substr(call, args_start, args_end)
        
        if (args == "" || args ~ /^[ \t]*$/) {
            replacement = "dispatch_0(" func_var ")"
        } else {
            arg_count = 1
            temp_args = args
            while (match(temp_args, /,/)) {
                arg_count++
                temp_args = substr(temp_args, RSTART + 1)
            }
            replacement = "dispatch_" arg_count "(" func_var ", " args ")"
        }
        line = before replacement after
    }
    print line
}' "$INPUT_FILE" > "$TMP_FILE"

# Generate dispatch functions
{
    echo "# AWK Dispatch Functions"
    
    for argc in $(seq 0 10); do
        funcs=$(awk -F'|' -v n="$argc" '$2 == n {print $1}' "$TMP_SIGS")
        
        echo ""
        printf "function dispatch_%d(func_name" "$argc"
        for i in $(seq 1 $argc); do printf ", arg%d" "$i"; done
        printf ") {\n"
        
        for func in $funcs; do
            printf "    if (func_name == \"%s\") return %s(" "$func" "$func"
            for i in $(seq 1 $argc); do
                [ $i -gt 1 ] && printf ", "
                printf "arg%d" "$i"
            done
            printf ")\n"
        done
        
        printf "    printf(\"ERROR: dispatch_%d: '%%s'\\\\n\", func_name) > \"/dev/stderr\"\n" "$argc"
        printf "    return \"\"\n}\n"
    done
    
    # NOTE: Special dispatch wrappers (dispatch_tokenizer, dispatch_evaluator, etc.)
    # are NO LONGER NEEDED - code now uses dispatch_N directly
    
    cat "$TMP_FILE"
} > "${TMP_FILE}.final"

if [ -n "$OUTPUT_FILE" ]; then
    mv "${TMP_FILE}.final" "$OUTPUT_FILE"
    echo "Output: $OUTPUT_FILE" >&2
else
    cat "${TMP_FILE}.final"
fi

rm -f "${TMP_FILE}.final"
