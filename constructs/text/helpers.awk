# Text Token Helpers
# Utility functions for working with text tokens

@include "core/token_tree.awk"

# Collect text from child text tokens
# Iterates through children of a token and collects text from text-type children
# Parameters:
#   token_id - parent token ID
# Returns: concatenated text from all text-type children (with newlines between if multiple)
function collect_text_from_children(token_id,    child_count, i, child_id, result, child_text) {
    result = ""
    child_count = get_children_count(token_id)
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        if (get_token_type(child_id) == "text") {
            # Use get_token_value directly for text tokens
            child_text = get_token_value(child_id)
            if (result != "") {
                result = result "\n"
            }
            result = result child_text
        }
    }
    
    return result
}

