# Dispatch Function Stubs for Unit Tests
# Provides dispatch functions that use indirect call (GNU AWK feature)
# This allows unit tests to work without compiled engine from build_engine.sh
#
# Usage:
#   @include "fixtures/dispatch_stubs.awk"
#
# Note: Include this AFTER construct definitions and tokenizers/evaluators,
#       but BEFORE core modules that use dispatch functions

# Dispatch to evaluator function
# Parameters:
#   func_name - name of evaluator function
#   token_id - token ID to evaluate
#   depth - optional depth parameter (for include)
# Returns: evaluated token ID or 0
function dispatch_evaluator(func_name, token_id, depth) {
    # Use indirect function call (GNU AWK feature)
    if (depth != "") {
        return @func_name(token_id, depth)
    }
    return @func_name(token_id)
}

# Dispatch to tokenizer function
# Parameters:
#   func_name - name of tokenizer function
#   marker_text - marker content without {{ }}
#   pos - position in original text
#   start_line - starting line number
#   construct_type - construct type (for reference)
# Returns: token ID or 0
function dispatch_tokenizer(func_name, marker_text, pos, start_line, construct_type) {
    # Use indirect function call (GNU AWK feature)
    if (func_name != "") {
        return @func_name(marker_text, pos, start_line)
    }
    return 0
}

# Dispatch to branch parser function
# Parameters:
#   construct_type - construct type
#   content - content to parse
#   token_id - parent token ID
#   start_line - starting line number
# Returns: 0 (void function, modifies token_id)
function dispatch_branch_parser(construct_type, content, token_id, start_line) {
    func_name = get_branch_parser(construct_type)
    if (func_name != "") {
        return @func_name(content, token_id, start_line)
    }
    return 0
}

# Dispatch to content parser function
# Parameters:
#   construct_type - construct type
#   content - full content
#   start_pos - position after opening marker
#   token_id - token ID
# Returns: position after parsed content
function dispatch_content_parser(construct_type, content, start_pos, token_id) {
    func_name = get_content_parser(construct_type)
    if (func_name != "") {
        return @func_name(content, start_pos, token_id)
    }
    return start_pos
}

