# Comparison Operators Evaluator
# Evaluates: left OP right where OP is: ==, !=, >, <, >=, <=
# Note: DEBUG_FILE_NAME is automatically set by build_engine.sh

# Evaluate comparison condition
# Parameters:
#   op - comparison operator
#   parts - array with parsed parts
# Returns: 1 if comparison is true, 0 otherwise
function evaluate_comparison(op, parts,    left, right, var_name, func_name, func_arg, base_value, left_val, i, right_start) {
    # Get left value - reconstruct from parts[2] onwards until we find the right value
    # Format is: op|left|right, but left may contain | (e.g., VAR||)
    # parse_comparison returns: op|parsed_left|right
    # where parsed_left can be "VAR||" or "VAR||func||arg" format
    # So we need to find where left ends and right begins
    # Right is always the LAST non-empty part after the operator
    # Find right by going backwards from the end
    right_start = 0
    for (i = length(parts); i >= 3; i--) {
        if (parts[i] != "") {
            right_start = i
            break
        }
    }
    if (right_start == 0) {
        # Fallback: use parts[3] if it exists
        right_start = 3
    }
    
    # Reconstruct left from parts[2] to right_start-1
    # But if parsed_left format is "VAR||type", we need to extract "type" as the actual var name
    # Find the last non-empty part before right_start - that's the actual variable name
    actual_var_start = 0
    for (i = right_start - 1; i >= 2; i--) {
        if (parts[i] != "") {
            actual_var_start = i
            break
        }
    }
    if (actual_var_start == 0) {
        actual_var_start = 2
    }
    
    # Reconstruct left from parts[2] to actual_var_start
    left = parts[2]
    for (i = 3; i <= actual_var_start; i++) {
        if (parts[i] != "") {
            left = left "|" parts[i]
        } else {
            left = left "|"
        }
    }
    
    # Extract variable name - use the last non-empty part before right
    var_name = parts[actual_var_start]
    func_name = ""
    func_arg = ""
    base_value = get_var(var_name)
    
    if (func_name != "") {
        left_val = process_variable_function(var_name, func_name, func_arg, base_value)
    } else {
        left_val = base_value
    }
    
    # Get right value - use right_start to find correct position
    # right_start was calculated above based on parts structure
    right = ""
    if (right_start <= length(parts)) {
        right = parts[right_start]
    }
    # Note: quotes are already removed by parse_comparison, but check anyway for safety
    if (match(right, /^['"'"'"](.*)['"'"'"]$/)) {
        right = substr(right, RSTART + 1, RLENGTH - 2)
    }
    
    # Debug output - always log for type comparisons
    if (var_name == "type") {
        log_debug("evaluate_comparison: var_name=[%s] base_value=[%s] left_val=[%s] right=[%s] op=[%s] result=%d context_level=%d", var_name, base_value, left_val, right, op, (left_val == right ? 1 : 0), context_level)
        # Also check ENVIRON directly
        if (var_name in ENVIRON) {
            log_debug("evaluate_comparison: ENVIRON[%s]=[%s]", var_name, ENVIRON[var_name])
        }
        # Check all parts for debugging
        log_debug("evaluate_comparison: parts count=%d right_start=%d actual_var_start=%d", length(parts), right_start, actual_var_start)
        for (i = 1; i <= length(parts) && i <= 5; i++) {
            log_debug("evaluate_comparison: parts[%d]=[%s]", i, parts[i])
        }
    }
    
    if (op == "!=") {
        return (left_val != right) ? 1 : 0
    }
    if (op == "==") {
        return (left_val == right) ? 1 : 0
    }
    if (op == ">") {
        return (left_val + 0 > right + 0) ? 1 : 0
    }
    if (op == ">=") {
        return (left_val + 0 >= right + 0) ? 1 : 0
    }
    if (op == "<") {
        return (left_val + 0 < right + 0) ? 1 : 0
    }
    if (op == "<=") {
        return (left_val + 0 <= right + 0) ? 1 : 0
    }
    
    return 0
}

