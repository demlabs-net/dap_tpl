# COMMENT Construct Definition
# Registers COMMENT construct in the registry
# Comments are ignored during processing

BEGIN {
    # Register opening pattern for single-line comments
    register_opening_pattern("comment", "^![ \t]*(.*)$", "parse_comment_construct")
    
    # Register opening pattern for multi-line comments
    register_opening_pattern("comment_ml", "^!--(.*)$", "parse_comment_ml_construct")
    
    # Mark as self-contained (no closing tag needed)
    register_self_contained("comment")
    register_self_contained("comment_ml")
    
    # Register content parsers for special handling
    register_content_parser("comment", "parse_comment_content")
    register_content_parser("comment_ml", "parse_comment_ml_content")
    
    # Register evaluator (comments produce no output)
    register_evaluator("comment", "evaluate_comment")
    register_evaluator("comment_ml", "evaluate_comment")
    
    # Mark comments to skip empty text tokens when rendering
    # This prevents extra newlines from empty comment tokens
    register_skip_empty_text("comment")
    register_skip_empty_text("comment_ml")
}

