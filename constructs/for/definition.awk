# FOR Construct Definition
# Registers FOR construct in the registry
# Supports: {{#for item in ARRAY}} and {{#for key,val in DATA}} (destructuring)

BEGIN {
    # Register opening pattern
    register_opening_pattern("for", "^#for[ \t]+(.+)$", "parse_for_construct")
    
    # Register closing pattern  
    register_closing_pattern("for", "^/for$")
    
    # Register evaluator
    register_evaluator("for", "evaluate_for")
}

