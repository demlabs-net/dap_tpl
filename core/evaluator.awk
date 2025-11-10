# Evaluator - Dispatcher for evaluating tokens
# Uses indirect function calls to evaluate tokens based on their type

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/evaluators/if_evaluator.awk"
@include "core/evaluators/for_evaluator.awk"
@include "core/evaluators/set_evaluator.awk"
@include "core/evaluators/var_evaluator.awk"
@include "core/evaluators/awk_section_evaluator.awk"
@include "core/evaluators/text_evaluator.awk"

# Evaluate a token tree recursively
# Parameters:
#   token_id - token ID to evaluate
# Returns: evaluated token ID (may be same or new)
function evaluate_token(token_id,    token_type, evaluated_id, child_count, i, child_id, evaluated_child_id, new_children, new_child_count) {
    if (!token_exists(token_id)) {
        return 0
    }
    
    token_type = get_token_type(token_id)
    
    # Special handling for root token
    if (token_type == "root") {
        return evaluate_root(token_id)
    }
    
    # Use indirect function call to evaluate token based on type
    # Function name format: evaluate_<type>
    func_name = "evaluate_" token_type
    
    # Call evaluator function using indirect call
    evaluated_id = @func_name(token_id)
    
    if (evaluated_id == 0) {
        # Evaluation failed or returned 0 - return original token
        return token_id
    }
    
    # Evaluate children recursively and rebuild children list
    child_count = get_children_count(evaluated_id)
    new_child_count = 0
    delete new_children
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(evaluated_id, i)
        evaluated_child_id = evaluate_token(child_id)
        
        if (evaluated_child_id > 0) {
            new_child_count++
            new_children[new_child_count] = evaluated_child_id
        }
    }
    
    # If children were evaluated, create new token with evaluated children
    if (new_child_count != child_count || child_count > 0) {
        # Create new token of same type with evaluated children
        new_token_id = create_token(get_token_type(evaluated_id), get_token_value(evaluated_id), "")
        # Copy metadata
        if (get_token_metadata(evaluated_id, "condition") != "") {
            set_token_metadata(new_token_id, "condition", get_token_metadata(evaluated_id, "condition"))
        }
        if (get_token_metadata(evaluated_id, "var_name") != "") {
            set_token_metadata(new_token_id, "var_name", get_token_metadata(evaluated_id, "var_name"))
        }
        if (get_token_metadata(evaluated_id, "has_else") != "") {
            set_token_metadata(new_token_id, "has_else", get_token_metadata(evaluated_id, "has_else"))
        }
        
        # Add evaluated children
        for (i = 1; i <= new_child_count; i++) {
            add_child(new_token_id, new_children[i])
        }
        
        return new_token_id
    }
    
    return evaluated_id
}

# Evaluate entire tree starting from root
# Parameters:
#   root_token_id - root token ID
# Returns: evaluated root token ID
function evaluate_tree(root_token_id) {
    # Initialize context
    clear_contexts()
    push_context()  # Root context
    
    # Export ENVIRON variables to context
    export_environ_to_context()
    
    return evaluate_token(root_token_id)
}

# Export ENVIRON variables to root context
function export_environ_to_context(    var_name) {
    for (var_name in ENVIRON) {
        set_var(var_name, ENVIRON[var_name])
    }
}

# Evaluate root token (special case)
function evaluate_root(token_id,    child_count, i, child_id, evaluated_child_id, result_token_id) {
    # Root token just evaluates all children
    result_token_id = create_token("root", "", "")
    
    child_count = get_children_count(token_id)
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        evaluated_child_id = evaluate_token(child_id)
        if (evaluated_child_id > 0) {
            add_child(result_token_id, evaluated_child_id)
        }
    }
    
    return result_token_id
}
