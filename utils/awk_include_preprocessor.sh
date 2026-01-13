#!/bin/sh
# AWK Include Preprocessor - Wrapper for pure AWK version
set -e

if [ $# -lt 1 ]; then
    cat << EOF
Usage: $0 <input_file> [base_dir]
Processes @include directives in AWK files recursively.
EOF
    exit 1
fi

INPUT_FILE="$1"
BASE_DIR="${2:-.}"

[ ! -f "$INPUT_FILE" ] && echo "Error: File not found: $INPUT_FILE" >&2 && exit 1

# Use pure AWK preprocessor
exec awk -f "$(dirname "$0")/awk_include_preprocessor.awk" -v basedir="$BASE_DIR" "$INPUT_FILE"
