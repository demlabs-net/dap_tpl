# SET Construct Evaluator
# Evaluates set constructs: {{#set VAR=value}}...{{/set}}

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/marker_parser.awk"
@include "core/construct_registry.awk"

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
            parsed_expr = parse_var_expr(marker_text)
            var_name = get_var_name(parsed_expr)
            func_name = get_func_name(parsed_expr)
            func_arg = get_func_arg(parsed_expr)
            
            base_value = get_var(var_name)
            if (base_value != "" && !(var_name in ENVIRON)) {
                ENVIRON[var_name] = base_value
            }
            
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
        set_var(var_name, evaluated_value)
        ENVIRON[var_name] = evaluated_value
        
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
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        add_child(result_token_id, child_id)
    }
    
    return result_token_id
}

