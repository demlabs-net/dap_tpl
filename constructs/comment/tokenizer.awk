# COMMENT Construct Tokenizer
# Parses comment constructs: {{! comment }} and {{!-- multi-line --}}

@include "core/token_tree.awk"

# Parse single-line comment: {{! comment }}
function parse_comment_construct(marker_text, pos, start_line,    metadata, token_id, comment_text) {
    if (match(marker_text, /^![ \t]*(.*)$/)) {
        comment_text = substr(marker_text, RSTART + 2)
        gsub(/^[ \t]+|[ \t]+$/, "", comment_text)
        delete metadata
        metadata["start_line"] = start_line
        return create_token("comment", comment_text, metadata)
    }
    return 0
}

# Parse multi-line comment start: {{!--
# Note: Multi-line comments are handled specially - they need to find --}} closing
function parse_comment_ml_construct(marker_text, pos, start_line,    metadata, token_id) {
    if (match(marker_text, /^!--(.*)$/)) {
        delete metadata
        metadata["start_line"] = start_line
        # Mark as multi-line - tokenizer_core will handle finding --}}
        return create_token("comment_ml", "", metadata)
    }
    return 0
}

