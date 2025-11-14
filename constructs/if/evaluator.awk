# IF Construct Evaluator
# Evaluates if constructs with improved syntax:
#   {{#if VAR}} - simple boolean
#   {{#if VAR != 0}} - comparison
#   {{#if VAR > 5}} - numeric comparison
#   {{#if VAR contains 'text'}} - substring check
#   {{#if VAR && VAR2}} - logical AND
#   {{#if VAR || VAR2}} - logical OR
#   {{#if !VAR}} - logical NOT
# Note: DEBUG_FILE_NAME is automatically set by build_engine.sh

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/marker_parser.awk"
@include "core/condition_parser.awk"
@include "core/metadata_helpers.awk"
@include "core/conditional_evaluator_helpers.awk"
@include "core/debug.awk"

# Evaluate if condition (using improved parser)
# Parameters:
#   condition_expr - condition expression
# Returns: 1 if true, 0 if false
function evaluate_if_condition(condition_expr,    parsed_cond) {
    parsed_cond = parse_condition(condition_expr)
    return evaluate_parsed_condition(parsed_cond)
}

# Evaluate if token with elif/else support
# Parameters:
#   token_id - if token ID
# Returns: evaluated token ID with appropriate branch content
function evaluate_if(token_id,    condition, condition_result, child_count, i, child_id, child_type, elif_token_id, else_token_id, result_token_id, elif_condition, elif_result, elif_found) {
    condition = get_condition(token_id)
    if (condition == "") {
        return token_id
    }
    
    # Debug output - check token_id BEFORE evaluation
    if (condition ~ /type.*==.*void/) {
        log_debug("evaluate_if START: token_id=%d token_type=%s child_count=%d", token_id, get_token_type(token_id), get_children_count(token_id))
        # List all children
        child_count_before = get_children_count(token_id)
        for (i = 1; i <= child_count_before; i++) {
            child_id_before = get_child(token_id, i)
            log_debug("  child[%d]: id=%d type=%s", i, child_id_before, get_token_type(child_id_before))
        }
    }
    
    # Evaluate main condition
    condition_result = evaluate_if_condition(condition)
    
    # Debug output
    if (condition ~ /type.*==.*void/) {
        log_debug("condition=[%s] result=%d", condition, condition_result)
        log_debug("token_id=%d child_count=%d AFTER condition evaluation", token_id, get_children_count(token_id))
    }
    
    # Find elif and else tokens
    child_count = get_children_count(token_id)
    
    delete elif_tokens
    delete elif_conditions
    elif_count = 0
    else_token_id = 0
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        child_type = get_token_type(child_id)
        
        # Debug output
        if (condition ~ /type.*==.*void/) {
            log_debug("child[%d]: id=%d type=%s", i, child_id, child_type)
        }
        
        if (child_type == "elif") {
            elif_count++
            elif_tokens[elif_count] = child_id
            elif_conditions[elif_count] = get_token_metadata(child_id, "condition")
        } else if (child_type == "else") {
            else_token_id = child_id
        }
    }
    
    # Debug output
    if (condition ~ /type.*==.*void/) {
        log_debug("elif_count=%d else_token_id=%d", elif_count, else_token_id)
    }
    
    # Create result token
    result_token_id = create_empty_result()
    
    # Debug output
    if (condition ~ /type.*==.*void/) {
        log_debug("condition_result=%d (1=true, 0=false), taking %s branch", condition_result, (condition_result ? "TRUE" : "FALSE"))
    }
    
    if (condition_result) {
        # True - copy if branch children (excluding elif/else)
        # Debug output
        if (condition ~ /type.*==.*void/) {
            log_debug("copying main branch children")
        }
        copy_main_branch_children(token_id, result_token_id, "elif else")
        
        # Debug output
        if (condition ~ /type.*==.*void/) {
            log_debug("result_token_id=%d result_children=%d", result_token_id, get_children_count(result_token_id))
        }
    } else {
        # False - check elif branches
        elif_found = 0
        for (i = 1; i <= elif_count; i++) {
            elif_condition = elif_conditions[i]
            elif_result = evaluate_if_condition(elif_condition)
            if (elif_result) {
                # This elif is true - use its content
                elif_token_id = elif_tokens[i]
                copy_branch_children(elif_token_id, result_token_id)
                elif_found = 1
                break
            }
        }
        
        # If no elif matched, use else if present
        if (!elif_found && else_token_id > 0) {
            # Debug output
            if (condition ~ /type.*==.*void/) {
                log_debug("using else branch, else_token_id=%d", else_token_id)
            }
            copy_branch_children(else_token_id, result_token_id)
            
            # Debug output
            if (condition ~ /type.*==.*void/) {
                log_debug("result_token_id=%d result_children=%d after else", result_token_id, get_children_count(result_token_id))
            }
        }
    }
    
    return result_token_id
}

