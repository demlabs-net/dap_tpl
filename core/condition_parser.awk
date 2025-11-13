# Condition Parser - Refactored Version
# Main entry point for parsing and evaluating conditions
# Uses modular condition parsers and evaluators from conditions/ directory
#
# Supports: VAR, VAR != 0, VAR > 5, VAR contains 'text', VAR in LIST, VAR matches 'pattern'
# Also supports: VAR && VAR2, VAR || VAR2, !VAR

# Load all condition modules (parsers and evaluators)
@include "conditions/condition_loader.awk"

# Parse condition expression with operators
# Parameters:
#   condition_expr - condition expression
# Returns: parsed condition structure (for evaluation)
function parse_condition(condition_expr,    trimmed, result) {
    trimmed = condition_expr
    gsub(/^[ \t]+|[ \t]+$/, "", trimmed)
    
    if (trimmed == "") {
        return ""
    }
    
    # Check for logical operators (lowest priority)
    if (match(trimmed, /[ \t]+&&[ \t]+/)) {
        return parse_logical_and(trimmed)
    }
    if (match(trimmed, /[ \t]+\|\|[ \t]+/)) {
        return parse_logical_or(trimmed)
    }
    if (match(trimmed, /^![ \t]+/)) {
        return parse_logical_not(trimmed)
    }
    
    # Check for comparison operators
    # Note: Order matters - >= and <= must be checked before > and <
    if (match(trimmed, /[ \t]+!=[ \t]+/)) {
        return parse_comparison(trimmed, "!=", RSTART, RLENGTH)
    }
    if (match(trimmed, /[ \t]+==[ \t]+/)) {
        return parse_comparison(trimmed, "==", RSTART, RLENGTH)
    }
    if (match(trimmed, /[ \t]+>=[ \t]+/)) {
        return parse_comparison(trimmed, ">=", RSTART, RLENGTH)
    }
    if (match(trimmed, /[ \t]+<=[ \t]+/)) {
        return parse_comparison(trimmed, "<=", RSTART, RLENGTH)
    }
    if (match(trimmed, /[ \t]+>[ \t]+/)) {
        return parse_comparison(trimmed, ">", RSTART, RLENGTH)
    }
    if (match(trimmed, /[ \t]+<[ \t]+/)) {
        return parse_comparison(trimmed, "<", RSTART, RLENGTH)
    }
    
    # Check for special operators
    if (match(trimmed, /[ \t]+contains[ \t]+/)) {
        return parse_contains(trimmed)
    }
    if (match(trimmed, /[ \t]+in[ \t]+/)) {
        return parse_in_list(trimmed)
    }
    if (match(trimmed, /[ \t]+matches[ \t]+/)) {
        return parse_matches(trimmed)
    }
    
    # Simple variable check
    return parse_simple_var(trimmed)
}

# Evaluate parsed condition
# Parameters:
#   parsed_cond - parsed condition from parse_condition()
# Returns: 1 if true, 0 if false
function evaluate_parsed_condition(parsed_cond,    parts, op, i) {
    if (parsed_cond == "") {
        return 0
    }
    
    split(parsed_cond, parts, "|")
    op = parts[1]
    
    # Logical operators
    if (op == "AND") {
        return evaluate_logical_and(parts)
    }
    if (op == "OR") {
        return evaluate_logical_or(parts)
    }
    if (op == "NOT") {
        return evaluate_logical_not(parts)
    }
    
    # Comparison operators
    if (op == "!=" || op == "==" || op == ">" || op == ">=" || op == "<" || op == "<=") {
        return evaluate_comparison(op, parts)
            }
    
    # Special operators
    if (op == "contains") {
        return evaluate_contains(parts)
    }
    if (op == "in") {
        return evaluate_in_list(parts)
    }
    if (op == "matches") {
        return evaluate_matches(parts)
    }
    
    # Simple variable check - check if this is a simple variable
    # Format: VAR|| (no operator, just variable expression)
    if (parts[2] == "" && parts[3] == "" && op != "!=" && op != "==" && op != ">" && op != ">=" && op != "<" && op != "<=" && op != "contains" && op != "in" && op != "matches") {
        return evaluate_simple_var(parts)
    }
    
    # Default: treat as simple variable
    return evaluate_simple_var(parts)
}
