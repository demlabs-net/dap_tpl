# IF Construct Definition
# Registers IF construct in the registry

BEGIN {
    # Register opening pattern
    register_opening_pattern("if", "^#if[ \t]+(.+)$", "parse_if_construct")
    
    # Register closing pattern  
    register_closing_pattern("if", "^/if$")
    
    # Register special markers (branch markers)
    register_special_marker("if", "^else$", "else")
    register_special_marker("if", "^#elif[ \t]+(.+)$", "elif")
    
    # Register branch parser function
    register_branch_parser("if", "parse_if_branches")
    
    # Register evaluator
    register_evaluator("if", "evaluate_if")
}

