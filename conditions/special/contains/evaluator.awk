# Contains Operator Evaluator
# Evaluates: left contains 'text'

# Evaluate contains condition
# Parameters:
#   parts - array with parsed parts [1]=op, [2]=left, [3+]=right
# Returns: 1 if left contains right, 0 otherwise
# NODISPATCH: internal helper with special calling convention
function evaluate_contains(parts,    left, right, var_name, func_name, func_arg, base_value, left_val, i) {
    left = parts[2]
    
    var_name = get_var_name(left)
    func_name = get_func_name(left)
    func_arg = get_func_arg(left)
    base_value = get_var(var_name)
    
    if (func_name != "") {
        left_val = process_variable_function(var_name, func_name, func_arg, base_value)
    } else {
        left_val = base_value
    }
    
    # Get right value - find the last non-empty part
    right = ""
    for (i = length(parts); i >= 3; i--) {
        if (parts[i] != "") {
            right = parts[i]
            break
        }
    }
    # Remove quotes if present
    if (match(right, /^['"'"'"](.*)['"'"'"]$/)) {
        right = substr(right, RSTART + 1, RLENGTH - 2)
    }
    
    return (index(left_val, right) > 0) ? 1 : 0
}

