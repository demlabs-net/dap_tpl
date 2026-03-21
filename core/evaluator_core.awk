# Evaluator Core - Data-Driven Evaluator Dispatcher
# Uses registry to dispatch evaluation instead of hardcoded includes
# This is the universal evaluator that dispatches to construct-specific evaluators
# Note: DEBUG_FILE_NAME is automatically set by build_engine.sh

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/construct_registry.awk"
@include "core/renderer.awk"
@include "core/debug.awk"

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
        # Check if this root token has already been evaluated (e.g., returned by for/set)
        # If it has children that are already evaluated, return as-is
        # Otherwise, evaluate children normally
        child_count = get_children_count(token_id)
        if (child_count > 0) {
            # Check if children are already evaluated (they should be text tokens or other evaluated tokens)
            # For root tokens returned by for/set, children are already evaluated
            # For root tokens from tokenization, children need evaluation
            # We can distinguish by checking if this is a "fresh" root token (no metadata) vs evaluated one
            # Actually, we should always evaluate root tokens - the special handling above for for/set
            # ensures that root tokens returned by evaluators are handled correctly
            return evaluate_root(token_id)
        }
        return token_id
    }
    
    # Special handling for text token (no evaluation needed)
    if (token_type == "text") {
        return token_id
    }
    
    func_name = get_evaluator_function(token_type)
    if (func_name == "") {
        return token_id
    }

    if (token_type == "include") {
        evaluated_id = dispatch_2(func_name, token_id, 0)
    } else {
        evaluated_id = dispatch_1(func_name, token_id)
    }
    
    if (evaluated_id == 0) {
        # Evaluation failed or returned 0 - return original token
        return token_id
    }
    
    # Special handling for macro tokens - they need to process children BEFORE evaluation
    # Macros store their content from original children, so we skip child evaluation for them
    if (token_type == "macro") {
        # Macro evaluator already processed children and stored macro definition
        # Just return the evaluated token (empty text token)
        return evaluated_id
    }
    
    # Special handling for root tokens returned by evaluators (e.g., set, for)
    # These root tokens should be evaluated directly without re-evaluating children
    # The evaluator already set variables and returned root token with children
    if (get_token_type(evaluated_id) == "root" && token_type != "root") {
        # Root token returned by evaluator
        # For 'for' loops: children are already evaluated inside evaluate_for
        # For 'set' constructs: children need to be evaluated (they contain the content)
        # We need to distinguish between these cases
        child_count = get_children_count(evaluated_id)
        
        # Debug output (disabled by default - set DEBUG_EVAL_TOKEN=1 to enable)
        # if (ENVIRON["DEBUG_EVAL_TOKEN"] == "1" && token_type == "for") {
        #     printf "DEBUG evaluate_token: for returned root token_id=%d children=%d\n", evaluated_id, child_count > "/dev/stderr"
        # }
        
        if (child_count > 0) {
            # Check if this is from a 'for' loop - if so, children are already evaluated
            # For 'for' loops, we can return the root token as-is
            # For 'set' constructs, we need to evaluate children
            if (token_type == "for") {
                # 'for' loop already evaluated its children - return as-is
                # Debug output (disabled by default - set DEBUG_EVAL_TOKEN=1 to enable)
                # if (ENVIRON["DEBUG_EVAL_TOKEN"] == "1") {
                #     printf "DEBUG evaluate_token: returning root token as-is, children=%d\n", child_count > "/dev/stderr"
                # }
                return evaluated_id
            } else {
                # Other constructs (e.g., 'set') - evaluate children
                new_child_count = 0
                delete new_children
                for (i = 1; i <= child_count; i++) {
                    child_id = get_child(evaluated_id, i)
                    child_type = get_token_type(child_id)
                    # Debug output for if tokens
                    if (child_type == "if") {
                        condition = get_token_metadata(child_id, "condition")
                        if (condition ~ /type.*==.*void/) {
                            log_debug("evaluate_token: BEFORE evaluate_token for set child, child_id=%d type=%s children=%d condition=[%s]", child_id, child_type, get_children_count(child_id), condition)
                        }
                    }
                    evaluated_child_id = evaluate_token(child_id)
                    if (child_type == "if") {
                        condition = get_token_metadata(child_id, "condition")
                        if (condition ~ /type.*==.*void/) {
                            log_debug("evaluate_token: AFTER evaluate_token for set child, evaluated_child_id=%d type=%s children=%d", evaluated_child_id, get_token_type(evaluated_child_id), get_children_count(evaluated_child_id))
                        }
                    }
                    if (evaluated_child_id > 0) {
                        new_child_count++
                        new_children[new_child_count] = evaluated_child_id
                    }
                }
                # Always create new root token with evaluated children
                # This ensures children are properly processed even if count matches
                new_token_id = create_token("root", "")
                for (i = 1; i <= new_child_count; i++) {
                    add_child(new_token_id, new_children[i])
                }
                return new_token_id
            }
        }
        return evaluated_id
    }
    
    # Block-set: {{#set VAR}}content{{/set}} — check BEFORE children evaluation
    if (evaluated_id == token_id && token_type == "set") {
        condition = get_token_metadata(token_id, "condition")
        block_set_children = get_children_count(token_id)
        if (condition !~ /=/ && block_set_children > 0) {
            _bs_var = condition
            gsub(/^[ \t]+|[ \t]+$/, "", _bs_var)
            if (_bs_var != "") {
                _bs_rendered = ""
                for (_bs_i = 1; _bs_i <= block_set_children; _bs_i++) {
                    _bs_child = get_child(token_id, _bs_i)
                    _bs_eval = evaluate_token(_bs_child)
                    _bs_rendered = _bs_rendered render_token(_bs_eval)
                }
                gsub(/^[ \t\n]+|[ \t\n]+$/, "", _bs_rendered)
                set_var(_bs_var, _bs_rendered)
                return create_token("root", "")
            }
        }
        return evaluated_id
    }

    # Evaluate children recursively and rebuild children list
    child_count = get_children_count(evaluated_id)

    if (get_token_type(evaluated_id) == "text" && child_count == 0) {
        return evaluated_id
    }

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

    if (new_child_count != child_count || child_count > 0) {
        # Create new token of same type with evaluated children
        new_token_id = create_token(get_token_type(evaluated_id), get_token_value(evaluated_id))
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

# Dispatch to actual evaluator function (compile-time generated)
# This function is defined by build_engine.sh before core files are included
# Parameters:
#   func_name - name of evaluator function
#   token_id - token ID to evaluate
#   depth - optional depth parameter (for include)
# Returns: evaluated token ID or 0
# NOTE: This function must be defined by build_engine.sh before @include of this file

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
function evaluate_root(token_id,    child_count, i, child_id, evaluated_child_id, result_token_id, child_type, grandchild_count, j, grandchild_id) {
    # Root token just evaluates all children
    result_token_id = create_token("root", "")
    
    child_count = get_children_count(token_id)
    
    # Debug output (disabled by default - set DEBUG_EVAL_ROOT=1 to enable)
    # if (ENVIRON["DEBUG_EVAL_ROOT"] == "1") {
    #     printf "DEBUG evaluate_root: token_id=%d children=%d\n", token_id, child_count > "/dev/stderr"
    # }
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        child_type = get_token_type(child_id)
        
        # Debug output (disabled by default - set DEBUG_EVAL_ROOT=1 to enable)
        # if (ENVIRON["DEBUG_EVAL_ROOT"] == "1") {
        #     printf "DEBUG evaluate_root: child[%d] id=%d type=%s children=%d\n", i, child_id, child_type, get_children_count(child_id) > "/dev/stderr"
        # }
        
        # If child is already a root token (e.g., returned by for/set), 
        # its children are already evaluated - just add it as-is
        if (child_type == "root") {
            # Root token children are already evaluated - add all its children directly
            grandchild_count = get_children_count(child_id)
            
            # Debug output (disabled by default - set DEBUG_EVAL_ROOT=1 to enable)
            # if (ENVIRON["DEBUG_EVAL_ROOT"] == "1") {
            #     printf "DEBUG evaluate_root: root child has %d grandchildren\n", grandchild_count > "/dev/stderr"
            # }
            
            for (j = 1; j <= grandchild_count; j++) {
                grandchild_id = get_child(child_id, j)
                add_child(result_token_id, grandchild_id)
                
                # Debug output (disabled by default - set DEBUG_EVAL_ROOT=1 to enable)
                # if (ENVIRON["DEBUG_EVAL_ROOT"] == "1" && j <= 3) {
                #     printf "DEBUG evaluate_root: added grandchild[%d] id=%d type=%s\n", j, grandchild_id, get_token_type(grandchild_id) > "/dev/stderr"
                # }
            }
        } else {
            # Normal child - evaluate it
            evaluated_child_id = evaluate_token(child_id)
            if (evaluated_child_id > 0) {
                add_child(result_token_id, evaluated_child_id)
            }
        }
    }
    
    # Debug output (disabled by default - set DEBUG_EVAL_ROOT=1 to enable)
    # if (ENVIRON["DEBUG_EVAL_ROOT"] == "1") {
    #     printf "DEBUG evaluate_root: FINAL result_token_id=%d children=%d\n", result_token_id, get_children_count(result_token_id) > "/dev/stderr"
    # }
    
    return result_token_id
}

