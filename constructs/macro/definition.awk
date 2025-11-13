BEGIN {
    register_opening_pattern("macro", "^#macro[ \t]+(.+)$", "parse_macro_construct")
    register_closing_pattern("macro", "^/macro$")
    register_evaluator("macro", "evaluate_macro")
}
