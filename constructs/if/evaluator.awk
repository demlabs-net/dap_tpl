# IF Construct Evaluator
# Evaluates if constructs with improved syntax:
#   {{#if VAR}} - simple boolean
#   {{#if VAR != 0}} - comparison
#   {{#if VAR > 5}} - numeric comparison
#   {{#if VAR contains 'text'}} - substring check
#   {{#if VAR && VAR2}} - logical AND
#   {{#if VAR || VAR2}} - logical OR
#   {{#if !VAR}} - logical NOT

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/marker_parser.awk"
@include "core/condition_parser.awk"
@include "core/metadata_helpers.awk"
@include "core/conditional_evaluator_helpers.awk"

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
    
    # Evaluate main condition
    condition_result = evaluate_if_condition(condition)
    
    # Find elif and else tokens
    child_count = get_children_count(token_id)
    delete elif_tokens
    delete elif_conditions
    elif_count = 0
    else_token_id = 0
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        child_type = get_token_type(child_id)
        if (child_type == "elif") {
            elif_count++
            elif_tokens[elif_count] = child_id
            elif_conditions[elif_count] = get_token_metadata(child_id, "condition")
        } else if (child_type == "else") {
            else_token_id = child_id
        }
    }
    
    # Create result token
    result_token_id = create_empty_result()
    
    if (condition_result) {
        # True - copy if branch children (excluding elif/else)
        copy_main_branch_children(token_id, result_token_id, "elif else")
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
            copy_branch_children(else_token_id, result_token_id)
        }
    }
    
    return result_token_id
}

