#!/bin/sh
# AWK create_token Normalizer
# Normalizes create_token calls - removes empty metadata arguments

set -e

if [ $# -lt 1 ]; then
    cat << EOF
Usage: $0 <input_file> [output_file]

Normalizes create_token calls:
- create_token(type, content, "") -> create_token(type, content)
- create_token(type, "") -> create_token(type)

Passing empty string instead of array causes type error in AWK.
EOF
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-}"

[ ! -f "$INPUT_FILE" ] && echo "Error: File not found: $INPUT_FILE" >&2 && exit 1

# Process file
awk '
{
    line = $0
    
    # Pattern 1: create_token(arg1, arg2, "")
    # Replace with: create_token(arg1, arg2)
    while (match(line, /create_token\([^,]+,[^,]+,[ \t]*""[ \t]*\)/)) {
        before = substr(line, 1, RSTART - 1)
        call = substr(line, RSTART, RLENGTH)
        after = substr(line, RSTART + RLENGTH)
        
        # Remove last argument ", "")"
        sub(/,[ \t]*""[ \t]*\)$/, ")", call)
        
        line = before call after
    }
    
    # Pattern 2: create_token(arg1, "")
    # Replace with: create_token(arg1)
    while (match(line, /create_token\([^,]+,[ \t]*""[ \t]*\)/)) {
        before = substr(line, 1, RSTART - 1)
        call = substr(line, RSTART, RLENGTH)
        after = substr(line, RSTART + RLENGTH)
        
        # Remove second argument ", "")"
        sub(/,[ \t]*""[ \t]*\)$/, ")", call)
        
        line = before call after
    }
    
    print line
}
' "$INPUT_FILE" > "${INPUT_FILE}.normalized"

# Output
if [ -n "$OUTPUT_FILE" ]; then
    mv "${INPUT_FILE}.normalized" "$OUTPUT_FILE"
    echo "Normalized create_token calls: $INPUT_FILE -> $OUTPUT_FILE" >&2
else
    cat "${INPUT_FILE}.normalized"
    rm -f "${INPUT_FILE}.normalized"
fi
