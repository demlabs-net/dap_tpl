# Module for processing if constructs
# Provides function process_if_construct() for evaluating conditions and processing content

@include "core/variable_functions.awk"

# Process if construct: evaluate condition and return processed content or empty string
# Parameters:
#   condition_expr - condition expression (VAR or VAR|function|args)
#   content - content to output if condition is true
#   else_content - content to output if condition is false (optional)
#   recursion_depth - current recursion depth (unused, kept for API compatibility)
# Returns: processed content if condition is true, else_content if false, empty string if no else
function process_if_construct(condition_expr, content, else_content, recursion_depth) {
    gsub(/^[ \t]+|[ \t]+$/, "", condition_expr)
    
    # Use evaluate_if_condition to avoid code duplication
    if (evaluate_if_condition(condition_expr)) {
        # True condition - return processed content
        return content
    } else {
        # False condition - return else content if provided
        if (else_content != "") {
            return else_content
        }
        return ""
    }
}

# Evaluate if condition and return boolean result
# Returns: 1 if condition is true, 0 if false
function evaluate_if_condition(condition_expr,    condition_value, cond_var, func_name, func_arg, cond_var_value, func_parts, var_name) {
    gsub(/^[ \t]+|[ \t]+$/, "", condition_expr)
    
    condition_value = ""
    if (match(condition_expr, /\|/)) {
        split(condition_expr, func_parts, "|")
        cond_var = func_parts[1]
        gsub(/^[ \t]+|[ \t]+$/, "", cond_var)
        func_name = func_parts[2]
        gsub(/^[ \t]+|[ \t]+$/, "", func_name)
        func_arg = ""
        if (length(func_parts) > 2) {
            func_arg = func_parts[3]
            gsub(/^[ \t]+|[ \t]+$/, "", func_arg)
        }
        
        cond_var_value = ""
        if (cond_var in vars) {
            cond_var_value = vars[cond_var]
        } else if (cond_var in ENVIRON) {
            cond_var_value = ENVIRON[cond_var]
        }
        
        condition_value = process_variable_function(cond_var, func_name, func_arg, cond_var_value)
    } else {
        var_name = condition_expr
        if (var_name in vars) {
            condition_value = vars[var_name]
        } else if (var_name in ENVIRON) {
            condition_value = ENVIRON[var_name]
        }
    }
    
    if (condition_value != "" && condition_value != "0" && condition_value != "false" && condition_value != "no") {
        return 1
    }
    return 0
}

