// Example 7: AWK and Shell Sections
// Demonstrates: embedded code execution for advanced generation
// See: docs/DAP_TPL_GUIDE.md#awk-sections

// AWK section for complex processing
{{AWK:}}
BEGIN {
    # Generate sequence of numbers
    for (i = 0; i < 10; i++) {
        print "#define VALUE_" i " " (i * 10)
    }
}
{{/AWK}}

// Shell section for system operations
{{SH:}}
echo "// Generated on: $(date)"
echo "// System: $(uname -s)"
{{/SH}}

// Combination with variables
{{#set MAX_COUNT=5}}
{{AWK:}}
BEGIN {
    max = ENVIRON["MAX_COUNT"]
    for (i = 0; i < max; i++) {
        print "#define ITEM_" i " " i
    }
}
{{/AWK}}

