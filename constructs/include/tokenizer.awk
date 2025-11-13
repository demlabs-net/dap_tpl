# INCLUDE Construct Tokenizer
# Parses include constructs: {{#include FILE}}

@include "core/token_tree.awk"
@include "core/tokenizer_helpers.awk"

function parse_include_construct(marker_text, pos, start_line) {
    return tokenize_simple_construct(marker_text, "include", 8, "include", start_line)
}

