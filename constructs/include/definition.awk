# INCLUDE Construct Definition
# Registers INCLUDE construct in the registry

BEGIN {
    # Register opening pattern
    register_opening_pattern("include", "^#include[ \t]+(.+)$", "parse_include_construct")
    
    # Register evaluator (include doesn't have closing tag)
    register_evaluator("include", "evaluate_include")
}

