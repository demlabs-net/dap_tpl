# Text Evaluator
# Passthrough evaluator for text tokens - no evaluation needed

@include "core/token_tree.awk"

# Evaluate text token (passthrough)
# Parameters:
#   token_id - text token ID
# Returns: same token ID
function evaluate_text(token_id) {
    # Text tokens don't need evaluation - return as is
    return token_id
}

