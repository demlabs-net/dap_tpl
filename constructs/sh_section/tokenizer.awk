# SH_SECTION Construct Tokenizer
# Parses SH sections: {{SH: ... }} (multi-line)

@include "core/token_tree.awk"

# Parse SH section construct marker
# Parameters:
#   marker_text - marker content without {{ }}
#   pos - position in original text
#   start_line - starting line number
# Returns: token ID or 0
function parse_sh_section_construct(marker_text, pos, start_line,    metadata, token_id) {
    if (match(marker_text, /^SH:[ \t]*$/)) {
        # {{SH:}} - multi-line shell section
        delete metadata
        metadata["start_line"] = start_line
        return create_token("sh_section", "", metadata)
    }
    return 0
}

