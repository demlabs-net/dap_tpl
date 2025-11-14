# SET Construct Evaluator
# Evaluates set constructs: {{#set VAR=value}}...{{/set}}
# Note: DEBUG_FILE_NAME is automatically set by build_engine.sh

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/marker_parser.awk"
@include "core/construct_registry.awk"
@include "core/debug.awk"

# Find innermost marker (one that doesn't contain other markers)
function find_innermost_marker(text, start_pos, marker_info,    pos, marker_pos, marker_start, marker_end, depth, i, marker_text) {
    pos = start_pos
    delete marker_info
    
    while (pos <= length(text)) {
        marker_pos = match(substr(text, pos), /{{/)
        if (marker_pos == 0) {
            break
        }
        
        marker_start = pos + marker_pos - 1
        depth = 0
        marker_end = 0
        for (i = marker_start + 2; i <= length(text) - 1; i++) {
            if (substr(text, i, 2) == "{{") {
                depth++
                i++
            } else if (substr(text, i, 2) == "}}") {
                if (depth == 0) {
                    marker_end = i + 2
                    break
                }
                depth--
                i++
            }
        }
        
        if (marker_end > 0) {
            marker_text = substr(text, marker_start + 2, marker_end - marker_start - 4)
            if (marker_text !~ /{{/) {
                marker_info["pos"] = marker_start
                marker_info["end"] = marker_end
                marker_info["text"] = marker_text
                return 1
            }
        }
        
        pos = marker_start + 2
    }
    
    return 0
}

# Evaluate variable expression in set value recursively
function evaluate_set_value(value_expr,    result, marker_info, marker_text, var_expr, parsed_expr, var_name, func_name, func_arg, base_value, var_value, before, after, max_iterations, iterations, parts_count_var, parts_count, part_var, p) {
    # Initialize result with value expression
    result = value_expr
    max_iterations = 100
    iterations = 0
    
    while (iterations < max_iterations) {
        iterations++
        delete marker_info
        if (!find_innermost_marker(result, 1, marker_info)) {
            break
        }
        
        marker_text = marker_info["text"]
        
        # Try to process marker using registered processors (e.g., AWK sections)
        processed_value = process_marker(marker_text)
        if (processed_value != "") {
            # Replace marker with processed value
            before = substr(result, 1, marker_info["pos"] - 1)
            after = substr(result, marker_info["end"])
            result = before processed_value after
        }
        else if (substr(marker_text, 1, 1) != "#" && substr(marker_text, 1, 1) != "/") {
            # Parse variable expression
            parsed_expr = parse_var_expr(marker_text)
            var_name = get_var_name(parsed_expr)
            func_name = get_func_name(parsed_expr)
            func_arg = get_func_arg(parsed_expr)
            
            # Get base value - get_var now properly searches contexts and ENVIRON
            # set_var always syncs to ENVIRON, so get_var will find variables set in previous iterations
            base_value = get_var(var_name)
            log_debug("evaluate_set_value: var_name=[%s] get_var returned=[%s]", var_name, base_value)
            
            if (func_name != "") {
                var_value = process_variable_function(var_name, func_name, func_arg, base_value)
                if (func_name == "split") {
                    parts_count_var = var_name "_parts_count"
                    if (parts_count_var in ENVIRON) {
                        parts_count = ENVIRON[parts_count_var]
                        for (p = 0; p < parts_count; p++) {
                            part_var = var_name "_parts_" p
                            if (part_var in ENVIRON) {
                                set_var(part_var, ENVIRON[part_var])
                            }
                        }
                        set_var(parts_count_var, parts_count)
                    }
                }
            } else {
                var_value = base_value
            }
            
            before = substr(result, 1, marker_info["pos"] - 1)
            after = substr(result, marker_info["end"])
            result = before var_value after
        } else {
            break
        }
    }
    
    return result
}

# Evaluate set token
function evaluate_set(token_id,    condition, var_name, var_value, child_count, i, child_id, result_token_id, metadata, evaluated_value, parts) {
    condition = get_token_metadata(token_id, "condition")
    if (condition == "") {
        return token_id
    }
    
    if (match(condition, /^([^=]+)=(.+)$/)) {
        split(condition, parts, "=")
        var_name = parts[1]
        gsub(/^[ \t]+|[ \t]+$/, "", var_name)
        var_value = substr(condition, index(condition, "=") + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", var_value)
        
        evaluated_value = evaluate_set_value(var_value)
        log_debug("evaluate_set: var_name=[%s] evaluated_value=[%s] before set_var", var_name, evaluated_value)
        set_var(var_name, evaluated_value)
        # set_var now automatically syncs to ENVIRON, so we don't need explicit sync here
        log_debug("evaluate_set: var_name=[%s] set_var done, ENVIRON[%s]=[%s] get_var=[%s]", var_name, var_name, ENVIRON[var_name], get_var(var_name))
        
        if (match(var_name, /^(.+)_parts_[0-9]+$/)) {
            vars[var_name] = evaluated_value
        }
    } else {
        return token_id
    }
    
    # Set constructs should produce no output - they only set variables
    # Return root token with children
    delete metadata
    result_token_id = create_token("root", "", metadata)
    
    child_count = get_children_count(token_id)
    
    # Debug output for nested if tokens
    if (var_name == "macro_name") {
        printf "DEBUG evaluate_set: token_id=%d child_count=%d\n", token_id, child_count > "/dev/stderr"
        for (i = 1; i <= child_count; i++) {
            child_id = get_child(token_id, i)
            child_type = get_token_type(child_id)
            child_children = get_children_count(child_id)
            condition = get_token_metadata(child_id, "condition")
            printf "DEBUG evaluate_set: token_id=%d child[%d]=%d type=%s children=%d condition=[%s]\n", token_id, i, child_id, child_type, child_children, condition > "/dev/stderr"
            # Check nested children
            if (child_type == "if" && child_children > 0) {
                for (j = 1; j <= child_children; j++) {
                    grandchild_id = get_child(child_id, j)
                    grandchild_type = get_token_type(grandchild_id)
                    grandchild_condition = get_token_metadata(grandchild_id, "condition")
                    grandchild_children = get_children_count(grandchild_id)
                    printf "DEBUG evaluate_set:   grandchild[%d]=%d type=%s children=%d condition=[%s]\n", j, grandchild_id, grandchild_type, grandchild_children, grandchild_condition > "/dev/stderr"
                }
            }
        }
    }
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        child_type = get_token_type(child_id)
        # Debug output for if tokens
        if (child_type == "if") {
            condition = get_token_metadata(child_id, "condition")
            if (condition ~ /type.*==.*void/) {
                printf "DEBUG evaluate_set: BEFORE add_child, child_id=%d type=%s children=%d condition=[%s]\n", child_id, child_type, get_children_count(child_id), condition > "/dev/stderr"
            }
        }
        add_child(result_token_id, child_id)
        # Debug output for if tokens
        if (child_type == "if") {
            condition = get_token_metadata(child_id, "condition")
            if (condition ~ /type.*==.*void/) {
                printf "DEBUG evaluate_set: AFTER add_child, child_id=%d type=%s children=%d\n", child_id, child_type, get_children_count(child_id) > "/dev/stderr"
            }
        }
    }
    
    # Debug output
    if (var_name == "macro_name") {
        printf "DEBUG evaluate_set: AFTER add_child, result_token_id=%d children=%d\n", result_token_id, get_children_count(result_token_id) > "/dev/stderr"
    }
    
    return result_token_id
}

