# If Evaluator
# Evaluates if constructs: {{#if VAR}}...{{/if}} and {{#if VAR}}...{{else}}...{{/if}}

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/marker_parser.awk"

# Evaluate if condition
# Parameters:
#   condition_expr - condition expression (VAR or VAR|function|args)
# Returns: 1 if true, 0 if false
function evaluate_if_condition(condition_expr,    parsed_expr, var_name, func_name, func_arg, base_value, result_value) {
    gsub(/^[ \t]+|[ \t]+$/, "", condition_expr)
    
    # Parse condition expression
    parsed_expr = parse_var_expr(condition_expr)
    var_name = get_var_name(parsed_expr)
    func_name = get_func_name(parsed_expr)
    func_arg = get_func_arg(parsed_expr)
    
    # Get base value
    base_value = get_var(var_name)
    
    # Process function if present
    if (func_name != "") {
        result_value = process_variable_function(var_name, func_name, func_arg, base_value)
    } else {
        result_value = base_value
    }
    
    # Evaluate as boolean (non-empty and not "0")
    if (result_value != "" && result_value != "0") {
        return 1
    }
    return 0
}

# Evaluate if token
# Parameters:
#   token_id - if token ID
# Returns: evaluated token ID with appropriate branch content
function evaluate_if(token_id,    condition, condition_result, child_count, i, child_id, child_type, else_token_id, result_token_id, metadata) {
    condition = get_token_metadata(token_id, "condition")
    if (condition == "") {
        return token_id
    }
    
    # Evaluate condition
    condition_result = evaluate_if_condition(condition)
    
    # Find else token if present
    else_token_id = 0
    child_count = get_children_count(token_id)
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        child_type = get_token_type(child_id)
        if (child_type == "else") {
            else_token_id = child_id
            break
        }
    }
    
    # Create result token with appropriate content
    delete metadata
    result_token_id = create_token("root", "", metadata)
    
    if (condition_result) {
        # True - copy if branch children (excluding else)
        for (i = 1; i <= child_count; i++) {
            child_id = get_child(token_id, i)
            if (get_token_type(child_id) != "else") {
                add_child(result_token_id, child_id)
            }
        }
    } else {
        # False - copy else branch children if present
        if (else_token_id > 0) {
            else_child_count = get_children_count(else_token_id)
            for (i = 1; i <= else_child_count; i++) {
                child_id = get_child(else_token_id, i)
                add_child(result_token_id, child_id)
            }
        }
        # If no else, result is empty (no children)
    }
    
    return result_token_id
}

