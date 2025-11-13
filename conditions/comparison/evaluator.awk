# Comparison Operators Evaluator
# Evaluates: left OP right where OP is: ==, !=, >, <, >=, <=

# Evaluate comparison condition
# Parameters:
#   op - comparison operator
#   parts - array with parsed parts
# Returns: 1 if comparison is true, 0 otherwise
function evaluate_comparison(op, parts,    left, right, var_name, func_name, func_arg, base_value, left_val, i, right_start) {
    # Get left value - reconstruct from parts[2] onwards until we find the right value
    # Format is: op|left|right, but left may contain | (e.g., VAR||)
    # So we need to find where left ends and right begins
    # Left part is everything from parts[2] to the last empty part before right
    left = parts[2]
    # If parts[3] is empty and parts[4] exists, then left is parts[2]|| and right is parts[4]
    # Otherwise, left is parts[2] and right is parts[3]
    if (parts[3] == "" && length(parts) > 3 && parts[4] != "") {
        # Left is VAR|| format, right is in parts[4]
        right_start = 4
    } else if (parts[3] == "" && length(parts) > 4 && parts[5] != "") {
        # Left is VAR|| format, right is in parts[5]
        right_start = 5
    } else {
        # Standard format: left is parts[2], right is parts[3]
        right_start = 3
    }
    
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

