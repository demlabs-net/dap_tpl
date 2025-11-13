# IF Construct Branch Parser
# Parses elif/else branches within if constructs
# Uses generic branch parser for simplified implementation

@include "core/token_tree.awk"
@include "core/construct_registry.awk"
@include "core/tokenizer_core.awk"
@include "core/generic_branch_parser.awk"

# Parse if construct with elif/else branches
# This function is called by tokenizer_core when it detects branch markers
function parse_if_branches(content, token_id, start_line) {
    parse_branches_generic(content, token_id, "if", start_line)
}

