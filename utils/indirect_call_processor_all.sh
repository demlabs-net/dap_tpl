#!/bin/sh
# AWK Indirect Call Processor - TRULY UNIVERSAL VERSION
# Generates dispatch for ALL functions except those explicitly marked with # NODISPATCH
# Philosophy: fail-fast on runtime errors, explicit marking for exclusions

set -e

INPUT_FILE="$1"
OUTPUT_FILE="${2:-}"

[ ! -f "$INPUT_FILE" ] && echo "Error: File not found: $INPUT_FILE" >&2 && exit 1

TMP_FILE=$(mktemp)
TMP_SIGS=$(mktemp)
trap 'rm -f "$TMP_FILE" "$TMP_SIGS"' EXIT

# Extract ALL function definitions, only skip if explicitly marked # NODISPATCH
grep -B1 "^function " "$INPUT_FILE" 2>/dev/null | \
awk '
BEGIN {
    next_is_nodispatch = 0
}

# Check for NODISPATCH marker in comment before function
/^#.*NODISPATCH/ {
    next_is_nodispatch = 1
    next
}

/^function / {
    line = $0
    sub(/^function[ \t]+/, "", line)
    fname = line
    sub(/\(.*/, "", fname)
    
    # ONLY exclusion: explicit NODISPATCH marker
    if (next_is_nodispatch) {
        next_is_nodispatch = 0
        next
    }
    
    # Skip log_debug - it gets special stub treatment
    if (fname == "log_debug") {
        next
    }
    
    # Extract parameters (without local variables)
    params = line
    sub(/^[^(]*\(/, "", params)
    sub(/\).*/, "", params)
    # Remove local variables (separated by 2+ spaces)
    sub(/,[ \t][ \t][ \t]*.*/, "", params)
    sub(/,[ \t]*,.*/, "", params)
    
    gsub(/[ \t]/, "", params)
    if (params == "") {
        print fname "|0"
    } else {
        print fname "|" split(params, arr, ",")
    }
    
    next_is_nodispatch = 0
}

{
    next_is_nodispatch = 0
}
' | sort -u > "$TMP_SIGS"

echo "# Found $(wc -l < "$TMP_SIGS") functions in input file" >&2

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
    echo "# AWK Dispatch Functions (All Functions)"
    
    # Add log_debug stub only if it's not already defined
    if ! grep -q "^function log_debug" "$TMP_FILE" 2>/dev/null; then
        echo ""
        echo "# Stub for log_debug (if not defined) - accepts variable args"
        echo "function log_debug(msg1, msg2, msg3, msg4, msg5) { }"
    fi
    echo ""
    
    # Find maximum argument count in the file
    max_argc=$(awk -F'|' '{print $2}' "$TMP_SIGS" | sort -n | tail -1)
    [ -z "$max_argc" ] && max_argc=0
    
    # Ensure we generate at least dispatch_0 through dispatch_3
    # (dispatch_3 is needed by special wrappers like dispatch_tokenizer)
    [ $max_argc -lt 3 ] && max_argc=3
    
    # Generate dispatch_N for all N from 0 to max_argc
    # This ensures all dispatch functions exist even if some arg counts have no functions
    for argc in $(seq 0 $max_argc); do
        # Get functions with this arg count from the file
        funcs=$(awk -F'|' -v n="$argc" '$2 == n {print $1}' "$TMP_SIGS")
        
        echo ""
        printf "function dispatch_%d(func_name" "$argc"
        for i in $(seq 1 $argc); do printf ", arg%d" "$i"; done
        printf ") {\n"
        
        # Add dispatches for found functions
        if [ -n "$funcs" ]; then
            for func in $funcs; do
                printf "    if (func_name == \"%s\") return %s(" "$func" "$func"
                for i in $(seq 1 $argc); do
                    [ $i -gt 1 ] && printf ", "
                    printf "arg%d" "$i"
                done
                printf ")\n"
            done
        fi
        
        # Always add error handler
        printf "    printf(\"ERROR: dispatch_%d: Unknown function '%%s'\\\\n\", func_name) > \"/dev/stderr\"\n" "$argc"
        printf "    return \"\"\n}\n"
    done
    
    # NOTE: Special dispatch wrappers (dispatch_tokenizer, dispatch_evaluator, etc.)
    # are defined in core/dispatch_helpers.awk and should be @include'd there
    # We don't generate them here to avoid duplication
    
    cat "$TMP_FILE"
} > "${TMP_FILE}.final"

if [ -n "$OUTPUT_FILE" ]; then
    mv "${TMP_FILE}.final" "$OUTPUT_FILE"
    echo "Output: $OUTPUT_FILE" >&2
else
    cat "${TMP_FILE}.final"
fi

rm -f "${TMP_FILE}.final"
