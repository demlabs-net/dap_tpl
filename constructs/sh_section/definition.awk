# SH_SECTION Construct Definition
# Registers SH_SECTION construct in the registry
# Usage: {{SH: ... }} (multi-line shell script)

BEGIN {
    # Register opening pattern for SH sections
    register_opening_pattern("sh_section", "^SH:[ \t]*$", "parse_sh_section_construct")
    
    # Register closing pattern
    register_closing_pattern("sh_section", "^/SH$")
    
    # Register evaluator
    register_evaluator("sh_section", "evaluate_sh_section")
}

