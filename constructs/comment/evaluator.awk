# COMMENT Construct Evaluator
# Comments produce no output - return empty text token

@include "core/token_tree.awk"

function evaluate_comment(token_id,    metadata, text_token_id) {
    # Comments produce no output
    # Mark as skip_empty_text so renderer knows to skip this empty token
    delete metadata
    metadata["skip_empty_text"] = 1
    text_token_id = create_token("text", "", metadata)
    return text_token_id
}

