# Text Token Processor
# Processes text tokens during rendering - handles text token filtering and processing

@include "core/token_tree.awk"
@include "core/construct_registry.awk"

# Process text child token
# Handles text token processing during rendering
# Parameters:
#   child_text - child token rendered text
#   child_type - child token type (should be "text")
#   prev_token_type - previous token type (or empty string)
#   prev_token_value - previous token rendered value (or empty string)
#   next_token_type - next token type (or empty string)
# Returns: "SKIP" to skip token, modified text value, or empty string to keep original
function process_text_child_token(child_text, child_type, prev_token_type, prev_token_value, next_token_type,    processed_result) {
    # Special case: if previous token is text with only newline, we need to check token before that
    # This is handled in root renderer by calling process_text_token for prev_prev_type
    # For now, just try processor for previous token (handles set -> text, text -> text cases)
    if (prev_token_type != "" && prev_token_value != "\n") {
        processed_result = process_text_token(child_text, prev_token_type, prev_token_value, next_token_type)
        if (processed_result == "SKIP") {
            return "SKIP"
        } else if (processed_result != "") {
            return processed_result
        }
    }
    
    # Return empty string to keep original value unchanged
    return ""
}

# Process text token after text token (for newline handling)
# Handles cases where text token follows a newline-only text token
# Parameters:
#   text_value - text token value
#   prev_token_type - previous token type (should be "text")
#   prev_token_value - previous token rendered value (should be "\n")
#   next_token_type - next token type (or empty string)
# Returns: "SKIP" to skip token, modified text value, or empty string to keep original
function process_text_after_newline(text_value, prev_token_type, prev_token_value, next_token_type) {
    # This is called when text token follows a newline-only text token
    # The actual processing for set -> \n -> text is handled in root renderer
    # by calling processor for token before newline
    # For now, return empty string to keep original
    return ""
}
