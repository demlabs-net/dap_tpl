# Metadata Helpers
# Helper functions for working with token metadata

@include "core/token_tree.awk"

# Get condition from token metadata (shortcut)
# Parameters:
#   token_id - token ID
# Returns: condition string or empty string
function get_condition(token_id) {
    return get_token_metadata(token_id, "condition")
}

# Create text result token (shortcut)
# Parameters:
#   text - text content
# Returns: token ID
function create_text_result(text,    metadata) {
    delete metadata
    return create_token("text", text, metadata)
}

# Create empty result token (for no-output constructs)
# Returns: token ID
# NODISPATCH: creates empty result array
function create_empty_result(    metadata) {
    delete metadata
    return create_token("root", "", metadata)
}

