# In List Operator Evaluator
# Evaluates: left in right

# Evaluate in list condition
# Parameters:
#   parts - array with parsed parts [1]=op, [2]=left, [3+]=right
# Returns: 1 if left is in right list, 0 otherwise
function evaluate_in_list(parts,    left, right, var_name, func_name, func_arg, base_value, left_val, i) {
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
    
    var_name = get_var_name(right)
    base_value = get_var(var_name)
    return process_in_list(left_val, base_value) == "1" ? 1 : 0
}

