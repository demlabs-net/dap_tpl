# SET Construct Tokenizer
# Parses set constructs: {{#set VAR=value}}...{{/set}}

@include "core/token_tree.awk"
@include "core/tokenizer_helpers.awk"

# Parse set construct marker
# Parameters:
#   marker_text - marker content without {{ }}
#   pos - position in original text
#   start_line - starting line number
# Returns: token ID or 0
function parse_set_construct(marker_text, pos, start_line) {
    return tokenize_simple_construct(marker_text, "set", 4, "set", start_line)
}

