# SET Construct Text Token Processor
# Processes text tokens that follow set tokens - removes leading whitespace

@include "core/token_tree.awk"
@include "core/construct_registry.awk"

# Process text token after set token
# Handles cases where text token follows a set token and needs special processing
# Parameters:
#   text_value - text token value
#   prev_token_type - previous token type (should be "set")
#   prev_token_value - previous token rendered value (empty for set)
#   next_token_type - next token type (or empty string)
# Returns: "SKIP" to skip token, modified text value, or empty string to keep original
function process_text_after_set(text_value, prev_token_type, prev_token_value, next_token_type,    modified_value) {
    # This is called when text token follows a set token
    # Remove leading whitespace from text tokens that follow a set token
    # This handles cases like:
    #   "{{#set VAR=1}} Text" -> "Text"
    #   "{{#set VAR=1}}\n Text" -> "\nText"
    
    # Check if text starts with newline followed by whitespace
    if (text_value ~ /^\n[ \t]+/) {
        # Remove whitespace after newline
        modified_value = text_value
        gsub(/^\n[ \t]+/, "\n", modified_value)
        return modified_value
    }
    # Check if text starts with whitespace (spaces/tabs only, no newline)
    if (text_value ~ /^[ \t]+/) {
        # Remove leading whitespace
        modified_value = text_value
        gsub(/^[ \t]+/, "", modified_value)
        # If token became empty after removing whitespace, skip it
        if (modified_value == "") {
            return "SKIP"
        }
        return modified_value
    }
    
    # Return empty string to keep original value unchanged
    return ""
}

