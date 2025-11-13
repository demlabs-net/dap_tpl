# IF Construct Tokenizer
# Parses if constructs: {{#if VAR}}...{{/if}} and {{#if VAR}}...{{else}}...{{/if}}

@include "core/token_tree.awk"

# Parse if construct marker
# Parameters:
#   marker_text - marker content without {{ }}
#   pos - position in original text
#   start_line - starting line number
# Returns: token ID or 0
function parse_if_construct(marker_text, pos, start_line,    condition, metadata, token_id) {
    if (match(marker_text, /^#if[ \t]+(.+)$/)) {
        # {{#if VAR}}
        condition = substr(marker_text, RSTART + 4)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        
        delete metadata
        metadata["condition"] = condition
        metadata["start_line"] = start_line
        
        return create_token("if", "", metadata)
    }
    return 0
}

