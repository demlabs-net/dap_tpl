# FOR Construct Tokenizer
# Parses for constructs: {{#for item in ARRAY}} and {{#for key,val in DATA}}

@include "core/token_tree.awk"

# Parse for construct marker
# Parameters:
#   marker_text - marker content without {{ }}
#   pos - position in original text
#   start_line - starting line number
# Returns: token ID or 0
function parse_for_construct(marker_text, pos, start_line,    condition, metadata, token_id) {
    if (match(marker_text, /^#for[ \t]+(.+)$/)) {
        # {{#for item in ARRAY}} or {{#for key,val in DATA}}
        condition = substr(marker_text, RSTART + 5)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        
        delete metadata
        metadata["condition"] = condition
        metadata["start_line"] = start_line
        
        return create_token("for", "", metadata)
    }
    return 0
}

