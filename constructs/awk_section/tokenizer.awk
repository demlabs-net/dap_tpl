# AWK_SECTION Construct Tokenizer
# Parses AWK sections: {{AWK: ... }} (multi-line)

@include "core/token_tree.awk"

# Parse AWK section construct marker
# Parameters:
#   marker_text - marker content without {{ }}
#   pos - position in original text
#   start_line - starting line number
# Returns: token ID or 0
function parse_awk_section_construct(marker_text, pos, start_line,    metadata, token_id) {
    if (match(marker_text, /^AWK:[ \t]*$/)) {
        # {{AWK:}} - multi-line AWK section
        delete metadata
        metadata["start_line"] = start_line
        return create_token("awk_section", "", metadata)
    }
    return 0
}
