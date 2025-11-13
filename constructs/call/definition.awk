BEGIN {
    register_opening_pattern("call", "^#call[ \t]+(.+)$", "parse_call_construct")
    register_evaluator("call", "evaluate_call")
}
