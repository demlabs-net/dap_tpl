# FOR Construct Evaluator
# Evaluates for loops: {{#for item in ARRAY}} and {{#for key,val in DATA}} (destructuring)

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"

# Evaluate for token with support for destructuring
# Parameters:
#   token_id - for token ID
# Returns: evaluated token ID with loop iterations expanded
function evaluate_for(token_id,    condition, loop_vars, loop_var_count, array_name, separator, array_value, items, item_count, i, item, item_parts, part_count, result_token_id, child_count, j, child_id, cloned_child_id, metadata, old_values, v, var_name, old_value) {
    condition = get_token_metadata(token_id, "condition")
    if (condition == "") {
        return token_id
    }
    
    # Parse condition: "item in ARRAY" or "key,val in DATA" or "key,val in DATA|separator"
    separator = "|"  # Default separator
    if (match(condition, /^(.+)[ \t]+in[ \t]+(.+)$/)) {
        # Extract loop variables and array name
        split(condition, parts, /[ \t]+in[ \t]+/)
        loop_vars_str = parts[1]
        gsub(/^[ \t]+|[ \t]+$/, "", loop_vars_str)
        array_name = parts[2]
        gsub(/^[ \t]+|[ \t]+$/, "", array_name)
        
        # Check for explicit separator: ARRAY|separator
        if (match(array_name, /^(.+)\|(.+)$/)) {
            array_name = substr(array_name, 1, RSTART - 1)
            separator = substr(array_name, RSTART + length(array_name) + 2)
            gsub(/^[ \t]+|[ \t]+$/, "", separator)
        }
        
        # Parse loop variables (support destructuring: "key,val" or "key,val,third")
        loop_var_count = split(loop_vars_str, loop_vars, ",")
        for (v = 1; v <= loop_var_count; v++) {
            gsub(/^[ \t]+|[ \t]+$/, "", loop_vars[v])
        }
    } else {
        return token_id
    }
    
    # Get array value from context
    array_value = get_var(array_name)
    if (array_value == "") {
        # Empty array - return empty result
        delete metadata
        return create_token("root", "", metadata)
    }
    
    # Split array into items based on separator
    # Support both newline-separated (for file-based data) and custom separator
    if (separator == "|" && array_value ~ /\n/) {
        # Newline-separated array (file-based data) - use newline
        item_count = split(array_value, items, /\n/)
    } else {
        # Use specified separator (default: pipe)
        if (separator == "|") {
            item_count = split(array_value, items, /\|/)
        } else {
            # Custom separator - escape special regex chars
            escaped_sep = separator
            gsub(/[.*+?^${}()|[\]\\]/, "\\\\&", escaped_sep)
            item_count = split(array_value, items, escaped_sep)
        }
    }
    
    # Create result token
    delete metadata
    result_token_id = create_token("root", "", metadata)
    
    # Save old values of loop variables if they exist
    delete old_values
    for (v = 1; v <= loop_var_count; v++) {
        var_name = loop_vars[v]
        old_value = get_var(var_name)
        if (old_value != "") {
            old_values[var_name] = old_value
        }
    }
    
    # Push context for loop variables
    push_context()
    
    # Iterate over items
    for (i = 1; i <= item_count; i++) {
        item = items[i]
        gsub(/^[ \t]+|[ \t]+$/, "", item)
        
        if (item == "") {
            continue
        }
        
        # Set loop context variables
        # _index: 0-based index
        set_var("_index", i - 1)
        ENVIRON["_index"] = i - 1
        # _is_first: 1 for first element, 0 otherwise
        set_var("_is_first", (i == 1) ? "1" : "0")
        ENVIRON["_is_first"] = (i == 1) ? "1" : "0"
        # _is_last: 1 for last element, 0 otherwise
        set_var("_is_last", (i == item_count) ? "1" : "0")
        ENVIRON["_is_last"] = (i == item_count) ? "1" : "0"
        # _count: total number of items
        set_var("_count", item_count)
        ENVIRON["_count"] = item_count
        
        # Handle destructuring: split item and assign to multiple variables
        if (loop_var_count > 1) {
            # Multiple variables - split item by separator
            if (separator == "|") {
                part_count = split(item, item_parts, /\|/)
            } else {
                escaped_sep = separator
                gsub(/[.*+?^${}()|[\]\\]/, "\\\\&", escaped_sep)
                part_count = split(item, item_parts, escaped_sep)
            }
            
            # Assign parts to variables
            for (v = 1; v <= loop_var_count && v <= part_count; v++) {
                var_name = loop_vars[v]
                set_var(var_name, item_parts[v])
                ENVIRON[var_name] = item_parts[v]
            }
            # If more variables than parts, set remaining to empty
            for (v = part_count + 1; v <= loop_var_count; v++) {
                var_name = loop_vars[v]
                set_var(var_name, "")
                ENVIRON[var_name] = ""
            }
        } else {
            # Single variable - assign item directly
            var_name = loop_vars[1]
            set_var(var_name, item)
            ENVIRON[var_name] = item
        }
        
        # Clone and evaluate children for each iteration
        child_count = get_children_count(token_id)
        for (j = 1; j <= child_count; j++) {
            child_id = get_child(token_id, j)
            
            # Clone subtree for this iteration
            cloned_child_id = clone_subtree(child_id)
            if (cloned_child_id > 0) {
                # Evaluate cloned child recursively
                evaluated_child_id = evaluate_token(cloned_child_id)
                if (evaluated_child_id > 0) {
                    add_child(result_token_id, evaluated_child_id)
                }
            }
        }
    }
    
    # Pop context
    pop_context()
    
    # Restore old values if they existed
    for (var_name in old_values) {
        set_var(var_name, old_values[var_name])
        ENVIRON[var_name] = old_values[var_name]
    }
    
    return result_token_id
}

