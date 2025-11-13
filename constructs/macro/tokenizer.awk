@include "core/token_tree.awk"
@include "core/tokenizer_helpers.awk"

function parse_macro_construct(marker_text, pos, start_line) {
    return tokenize_simple_construct(marker_text, "macro", 6, "macro", start_line)
}
