# Tokenizer Helpers
# Helper functions for simplifying tokenizer implementations

@include "core/token_tree.awk"
@include "core/marker_utils.awk"

# Extract argument after keyword (e.g., "#set VAR=value" -> "VAR=value")
# Parameters:
#   marker_text - full marker text
#   keyword_len - length of keyword including # (e.g., 4 for "#set")
# Returns: extracted argument (trimmed)
function extract_keyword_arg(marker_text, keyword_len) {
    # Skip keyword and whitespace
    arg = substr(marker_text, keyword_len + 1)
    # Trim leading whitespace
    gsub(/^[ \t]+/, "", arg)
    return arg
}

# Create standard construct token with condition
# Parameters:
#   type - token type
#   condition - condition/argument string
#   start_line - starting line number
# Returns: token ID
function create_construct_token(type, condition, start_line,    metadata) {
    delete metadata
    metadata["condition"] = condition
    metadata["start_line"] = start_line
    return create_token(type, "", metadata)
}

# Generic tokenizer for simple constructs matching pattern: #keyword arg
# Parameters:
#   marker_text - marker content without {{ }}
#   keyword - keyword to match (e.g., "set", "include")
#   keyword_len - length of keyword (for extraction)
#   type - token type
#   start_line - starting line number
# Returns: token ID or 0
function tokenize_simple_construct(marker_text, keyword, keyword_len, type, start_line,    pattern, arg) {
    pattern = "^#" keyword "[ \t]+(.+)$"
    if (match(marker_text, pattern)) {
        arg = extract_keyword_arg(marker_text, keyword_len)
        return create_construct_token(type, arg, start_line)
    }
    return 0
}

