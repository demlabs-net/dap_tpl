# SET Construct Definition
# Registers SET construct in the registry

@include "core/construct_registry.awk"

# Filter text tokens around set constructs
# Skips whitespace-only text tokens that are adjacent to set tokens
# Parameters:
#   text_value - text token value
#   prev_token_type - previous token type
#   next_token_type - next token type
# Returns: 1 to skip token, 0 to keep token
function filter_set_text_token(text_value, prev_token_type, next_token_type,    modified_value) {
    # Filter whitespace-only text tokens
    if (text_value ~ /^[ \t]+$/) {
        # Skip if previous or next token is set
        if (prev_token_type == "set" || next_token_type == "set") {
            return "SKIP"
        }
    }
    
    # Remove leading whitespace from text tokens that follow a set token
    # This handles cases like:
    #   "{{#set VAR=1}} Text" -> "Text"
    #   "{{#set VAR=1}}\n Text" -> "\nText"
    #   "{{#set VAR=1}}\nFirst: " -> "\nFirst: " (keep newline, remove leading space if any)
    if (prev_token_type == "set") {
        # Check if text starts with newline followed by whitespace
        if (text_value ~ /^\n[ \t]+/) {
            # Remove whitespace after newline
            modified_value = text_value
            gsub(/^\n[ \t]+/, "\n", modified_value)
            return modified_value
        }
        # Check if text starts with whitespace (spaces/tabs only, no newline)
        else if (text_value ~ /^[ \t]+/) {
            # Remove leading whitespace
            modified_value = text_value
            gsub(/^[ \t]+/, "", modified_value)
            # If token became empty after removing whitespace, skip it
            if (modified_value == "") {
                return "SKIP"
            }
            return modified_value
        }
    }
    
    # Return empty string to keep original value unchanged
    return ""
}

BEGIN {
    # Register opening pattern
    register_opening_pattern("set", "^#set[ \t]+(.+)$", "parse_set_construct")
    
    # Register closing pattern  
    register_closing_pattern("set", "^/set$")
    
    # Register evaluator
    register_evaluator("set", "evaluate_set")
    
    # Register renderer for set tokens
    register_renderer("set", "render_set_token")
    
    # Set constructs produce no output - they only set variables
    register_skip_empty_text("set")
    
    # Register text token filter to skip whitespace around set tokens
    register_text_token_filter("set", "filter_set_text_token")
    
    # Register text token processor for handling text after set tokens
    register_text_token_processor("set", "process_text_after_set")
}

