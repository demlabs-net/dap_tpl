#!/bin/sh
# Multidimensional Array For-Loop Preprocessor - TRULY CORRECT VERSION
# Counts balance ONLY for the for-block, ignoring everything outside

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <input_file> <output_file>"
    exit 1
fi

INPUT="$1"
OUTPUT="$2"

awk '
BEGIN {
    in_for_block = 0
}

# Detect for (var in array[index])
/for[[:space:]]*\([[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+in[[:space:]]+[a-zA-Z_][a-zA-Z0-9_]*\[/ {
    line = $0
    
    indent_match = match(line, /^[[:space:]]*/)
    current_indent = substr(line, 1, RLENGTH)
    
    temp = line
    sub(/^[[:space:]]*for[[:space:]]*\([[:space:]]*/, "", temp)
    
    var_name = temp
    sub(/[[:space:]]+in.*/, "", var_name)
    
    sub(/^[^[:space:]]+[[:space:]]+in[[:space:]]+/, "", temp)
    array_expr = temp
    sub(/\)[[:space:]]*.*$/, "", array_expr)
    
    array_name = array_expr
    sub(/\[.*/, "", array_name)
    
    index_expr = array_expr
    sub(/^[^[]*\[/, "", index_expr)
    sub(/\].*/, "", index_expr)
    
    # Generate transformed code
    printf "%s# TRANSFORMED: for (%s in %s[%s])\n", current_indent, var_name, array_name, index_expr
    printf "%sfor (__combined_key__ in %s) {\n", current_indent, array_name
    printf "%s    if (index(__combined_key__, %s SUBSEP) == 1) {\n", current_indent, index_expr
    printf "%s        %s = substr(__combined_key__, length(%s SUBSEP) + 1)\n", current_indent, var_name, index_expr
    
    in_for_block = 1
    for_indent = current_indent
    brace_count = 1  # Start with 1 - the opening { of for
    
    next
}

# Process lines inside transformed block
in_for_block == 1 {
    line = $0
    
    # Count braces in this line BEFORE processing
    temp1 = line
    temp2 = line
    gsub(/[^{]/, "", temp1)
    gsub(/[^}]/, "", temp2)
    open_count = length(temp1)
    close_count = length(temp2)
    
    # Update balance
    brace_count = brace_count + open_count - close_count
    
    # Check if this line closes the for block
    if (brace_count == 0) {
        # This line contains the closing } for our for loop
        # Replace the LAST } in this line with } }
        result = ""
        last_brace_pos = 0
        
        # Find position of last }
        for (i = 1; i <= length(line); i++) {
            if (substr(line, i, 1) == "}") {
                last_brace_pos = i
            }
        }
        
        if (last_brace_pos > 0) {
            # Build result: everything before last }, then } }, then everything after
            before = substr(line, 1, last_brace_pos - 1)
            after = substr(line, last_brace_pos + 1)
            
            # Print the content before closing brace with extra indent
            if (before !~ /^[[:space:]]*$/) {
                print "        " before
            }
            
            # Print our two closing braces
            printf "%s    }\n", for_indent
            printf "%s}", for_indent
            
            # Print content after closing brace if any (should be just whitespace)
            if (after !~ /^[[:space:]]*$/) {
                print after
            } else {
                print ""
            }
        }
        
        # Exit for block processing
        in_for_block = 0
        next
    }
    
    # Regular line inside for block - add extra indentation
    print "        " line
    next
}

# Regular lines outside for block
{
    print
}
' "$INPUT" > "$OUTPUT"

echo "Processed: $INPUT -> $OUTPUT"
