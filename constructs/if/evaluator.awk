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
function evaluate_if_condition(condition_expr,    parsed_cond, result) {
    if (DEBUG_ENABLED) {
        printf "DEBUG evaluate_if_condition: condition_expr=[%s] DEBUG_FILE_NAME=[%s]\n", condition_expr, DEBUG_FILE_NAME > "/dev/stderr"
    }
    
    
    parsed_cond = parse_condition(condition_expr)
    if (DEBUG_ENABLED) {
        printf "DEBUG evaluate_if_condition: parsed_cond=[%s]\n", parsed_cond > "/dev/stderr"
    }
    
    # Debug output for ALL conditions containing 'type'
    if (condition_expr ~ /type/) {
        # Check type variable value
        if ("type" in ENVIRON) {
            if (DEBUG_ENABLED) {
                printf "DEBUG evaluate_if_condition: ENVIRON[type]=[%s]\n", ENVIRON["type"] > "/dev/stderr"
            }
        }
        type_val = get_var("type")
        if (DEBUG_ENABLED) {
            printf "DEBUG evaluate_if_condition: get_var(type)=[%s]\n", type_val > "/dev/stderr"
        }
    }
    
    result = evaluate_parsed_condition(parsed_cond)
    
    if (DEBUG_ENABLED) {
        printf "DEBUG evaluate_if_condition: result=%d\n", result > "/dev/stderr"
    }
    
    return result
}

# Evaluate if token with elif/else support
# Parameters:
#   token_id - if token ID
# Returns: evaluated token ID with appropriate branch content
function evaluate_if(token_id,    condition, condition_result, child_count, i, child_id, child_type, elif_token_id, else_token_id, result_token_id, elif_condition, elif_result, elif_found) {
    condition = get_condition(token_id)
    
    if (DEBUG_ENABLED) {
        printf "DEBUG evaluate_if START: token_id=%d token_type=%s child_count=%d condition=[%s]\n", token_id, get_token_type(token_id), get_children_count(token_id), condition > "/dev/stderr"
    }
    
    if (condition == "") {
        return token_id
    }
    
    # Debug output - check token_id BEFORE evaluation
    if (condition ~ /type.*==.*void/) {
        # List all children
        child_count_before = get_children_count(token_id)
        for (i = 1; i <= child_count_before; i++) {
            child_id_before = get_child(token_id, i)
            if (DEBUG_ENABLED) {
                printf "DEBUG evaluate_if: child[%d]: id=%d type=%s\n", i, child_id_before, get_token_type(child_id_before) > "/dev/stderr"
            }
        }
    }
    
    # Evaluate main condition
    condition_result = evaluate_if_condition(condition)
    
    # Debug output
    if (condition ~ /type.*==.*void/) {
        if (DEBUG_ENABLED) {
            printf "DEBUG evaluate_if: condition=[%s] condition_result=%d (1=true, 0=false)\n", condition, condition_result > "/dev/stderr"
        }
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
    }
    
    # Create result token
    result_token_id = create_empty_result()
    
    # Debug output
    if (condition ~ /type.*==.*void/) {
    }
    
    # Debug output
    if (condition ~ /type.*==.*void/) {
        if (DEBUG_ENABLED) {
            printf "DEBUG evaluate_if: condition_result=%d, taking %s branch\n", condition_result, (condition_result ? "TRUE" : "FALSE") > "/dev/stderr"
        }
    }
    
    if (condition_result) {
        # True - copy if branch children (excluding elif/else)
        # Debug output
        if (condition ~ /type.*==.*void/) {
            if (DEBUG_ENABLED) {
                printf "DEBUG evaluate_if: copying main branch children (TRUE branch)\n" > "/dev/stderr"
            }
        }
        copy_main_branch_children(token_id, result_token_id, "elif else")
        
        # Debug output
        if (condition ~ /type.*==.*void/) {
            if (DEBUG_ENABLED) {
                printf "DEBUG evaluate_if: result_token_id=%d result_children=%d\n", result_token_id, get_children_count(result_token_id) > "/dev/stderr"
            }
        }
    } else {
        # False - check elif branches
        if (condition ~ /type.*==.*void/) {
            if (DEBUG_ENABLED) {
                printf "DEBUG evaluate_if: condition is FALSE, checking elif/else branches\n" > "/dev/stderr"
            }
        }
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
            if (DEBUG_ENABLED) {
                printf "DEBUG evaluate_if: using else branch, else_token_id=%d\n", else_token_id > "/dev/stderr"
            }
            if (condition ~ /type.*==.*void/) {
            }
            copy_branch_children(else_token_id, result_token_id)
            
            # Debug output
            if (DEBUG_ENABLED) {
                printf "DEBUG evaluate_if: result_token_id=%d result_children=%d after else\n", result_token_id, get_children_count(result_token_id) > "/dev/stderr"
            }
            if (condition ~ /type.*==.*void/) {
            }
        } else {
            if (condition ~ /type.*==.*void/) {
                if (DEBUG_ENABLED) {
                    printf "DEBUG evaluate_if: NO else branch! elif_found=%d else_token_id=%d\n", elif_found, else_token_id > "/dev/stderr"
                }
            }
        }
    }
    
    return result_token_id
}

