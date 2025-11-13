@include "core/token_tree.awk"
function parse_call_construct(marker_text, pos, start_line,    condition, metadata, token_id) {
    if (match(marker_text, /^#call[ \t]+(.+)$/)) {
        condition = substr(marker_text, RSTART + 6)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        delete metadata
        metadata["condition"] = condition
        metadata["start_line"] = start_line
        return create_token("call", "", metadata)
    }
    return 0
}
