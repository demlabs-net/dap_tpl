# Simple Variable Evaluator
# Evaluates: VAR (simple boolean check)

# Evaluate simple variable condition
# Parameters:
#   parts - array with parsed parts
#   For simple var without operator: parts[1]=VAR, parts[2]=func (or empty), parts[3]=arg (or empty)
# Returns: 1 if variable is truthy (non-empty and not "0"), 0 otherwise
# NODISPATCH: internal helper with special calling convention
function evaluate_simple_var(parts,    var_name, func_name, func_arg, base_value, value) {
    # Parts come from split by "|", so:
    # - parts[1] is the variable name
    # - parts[2] is the function name (if present)
    # - parts[3] is the function argument (if present)
    
    var_name = parts[1]
    func_name = parts[2]
    func_arg = parts[3]
    
    # Get base variable value
    base_value = get_var(var_name)
    
    # Apply function if present
    if (func_name != "") {
        value = process_variable_function(var_name, func_name, func_arg, base_value)
    } else {
        value = base_value
    }
    
    # Boolean check: non-empty and not "0"
    if (value != "" && value != "0") {
        return 1
    }
    return 0
}
