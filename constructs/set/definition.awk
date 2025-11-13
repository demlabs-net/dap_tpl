# SET Construct Definition
# Registers SET construct in the registry

BEGIN {
    # Register opening pattern
    register_opening_pattern("set", "^#set[ \t]+(.+)$", "parse_set_construct")
    
    # Register closing pattern  
    register_closing_pattern("set", "^/set$")
    
    # Register evaluator
    register_evaluator("set", "evaluate_set")
}

