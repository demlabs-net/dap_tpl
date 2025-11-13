# AWK_SECTION Construct Definition
# Registers AWK_SECTION construct in the registry
# Usage: {{AWK: ... }} (multi-line AWK code)

BEGIN {
    # Register opening pattern for AWK sections
    register_opening_pattern("awk_section", "^AWK:[ \t]*$", "parse_awk_section_construct")
    
    # Register closing pattern
    register_closing_pattern("awk_section", "^/AWK$")
    
    # Register evaluator
    register_evaluator("awk_section", "evaluate_awk_section")
}
