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
    # Debug output (disabled by default - set DEBUG_FOR=1 to enable)
    # if (ENVIRON["DEBUG_FOR"] == "1") {
    #     printf "DEBUG evaluate_for: START token_id=%d children=%d\n", token_id, get_children_count(token_id) > "/dev/stderr"
    # }
    
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
        # But first, check if array_name contains | - if so, it might be a literal value
        # We need to distinguish between:
        #   - "item in ARRAY|separator" (variable ARRAY with explicit separator)
        #   - "item in a|b|c" (literal value a|b|c)
        # Strategy: Check if it's a variable with explicit separator (ARRAY|separator)
        # by checking if the part before | is a valid variable name and separator is a keyword
        original_array_name = array_name
        if (match(array_name, /\|/)) {
            # Try to split by LAST | to get array name and separator
            # This handles cases like "ARRAY|separator" where separator is a keyword
            last_pipe_pos = match(array_name, /\|[^|]*$/)
            if (last_pipe_pos > 0) {
                potential_array_name = substr(array_name, 1, last_pipe_pos - 1)
                potential_separator = substr(array_name, last_pipe_pos + 1)
                gsub(/^[ \t]+|[ \t]+$/, "", potential_array_name)
                gsub(/^[ \t]+|[ \t]+$/, "", potential_separator)
                
                # Check if separator is a keyword (space, pipe, newline, newline_double) or if variable exists
                is_separator_keyword = (potential_separator == "space" || potential_separator == "pipe" || potential_separator == "newline" || potential_separator == "newline_double" || potential_separator == " " || potential_separator == "")
                test_value = get_var(potential_array_name)
                
                if (test_value != "" || is_separator_keyword) {
                    # Variable exists or separator is a keyword - use as variable with separator
                    array_name = potential_array_name
                    separator = potential_separator
                    # Handle special separator keywords
                    if (separator == "space" || separator == " ") {
                        separator = " "
                    } else if (separator == "pipe") {
                        separator = "|"
                    } else if (separator == "newline") {
                        separator = "\n"
                    } else if (separator == "newline_double") {
                        separator = "\n\n"
                    }
                }
                # If variable not found and separator is not a keyword, array_name stays as literal (a|b|c)
            }
        }
        
        # Parse loop variables (support destructuring: "key,val" or "key,val,third")
        loop_var_count = split(loop_vars_str, loop_vars, ",")
        for (v = 1; v <= loop_var_count; v++) {
            gsub(/^[ \t]+|[ \t]+$/, "", loop_vars[v])
        }
    } else {
        return token_id
    }
    
    # Get array value from context, or use array_name as literal if it contains |
    array_value = get_var(array_name)
    
    # Debug output (disabled by default - set DEBUG_FOR=1 to enable)
    # if (ENVIRON["DEBUG_FOR"] == "1") {
    #     printf "DEBUG evaluate_for: array_name=[%s] array_value=[%s]\n", array_name, array_value > "/dev/stderr"
    # }
    
    # If variable not found and array_name contains |, use it as literal value
    if (array_value == "" && array_name ~ /\|/) {
        array_value = array_name
        separator = "|"
        # Debug output (disabled by default - set DEBUG_FOR=1 to enable)
        # if (ENVIRON["DEBUG_FOR"] == "1") {
        #     printf "DEBUG evaluate_for: using array_name as literal value=[%s]\n", array_value > "/dev/stderr"
        # }
    }
    
    if (array_value == "") {
        # Empty array - return empty result
        delete metadata
        # Debug output (disabled by default - set DEBUG_FOR=1 to enable)
        # if (ENVIRON["DEBUG_FOR"] == "1") {
        #     printf "DEBUG evaluate_for: empty array, returning empty root token\n" > "/dev/stderr"
        # }
        return create_token("root", "", metadata)
    }
    
    # Auto-detect separator if default (|) and value doesn't contain |
    if (separator == "|" && array_value !~ /\|/) {
        # No pipe found - check for other separators
        if (array_value ~ /\n/) {
            # Contains newline - use newline
            separator = "\n"
        } else if (array_value ~ /[ \t]/) {
            # Contains space/tab - use space
            separator = " "
        }
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
        } else if (separator == " " || separator == "space") {
            # Space separator - use regex to split by one or more spaces
            item_count = split(array_value, items, /[ \t]+/)
        } else if (separator == "" || separator == "newline") {
            # Empty separator or newline keyword
            item_count = split(array_value, items, /\n/)
        } else if (separator == "newline_double" || separator == "\n\n") {
            # Double newline separator - for multiline entries
            item_count = split(array_value, items, /\n\n/)
        } else {
            # Custom separator - escape special regex chars
            escaped_sep = separator
            gsub(/[.*+?^${}()|[\]\\]/, "\\\\&", escaped_sep)
            item_count = split(array_value, items, escaped_sep)
        }
    }
    
    # Debug output (disabled by default - set DEBUG_FOR=1 to enable)
    # if (ENVIRON["DEBUG_FOR"] == "1") {
    #     printf "DEBUG evaluate_for: item_count=%d\n", item_count > "/dev/stderr"
    # }
    
    # Create result token
    delete metadata
    result_token_id = create_token("root", "", metadata)
    
    # Debug output (disabled by default - set DEBUG_FOR=1 to enable)
    # if (ENVIRON["DEBUG_FOR"] == "1") {
    #     printf "DEBUG evaluate_for: created result_token_id=%d type=%s\n", result_token_id, get_token_type(result_token_id) > "/dev/stderr"
    # }
    
    # Save old values of loop variables if they exist
    delete old_values
    for (v = 1; v <= loop_var_count; v++) {
        var_name = loop_vars[v]
        old_value = get_var(var_name)
        if (old_value != "") {
            old_values[var_name] = old_value
        }
    }
    
    # DON'T push context for loop - use parent context
    # This allows {{#set}} inside for to modify parent scope variables
    # Only loop variables are isolated
    
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
            child_type = get_token_type(child_id)
            
            # Debug output for set tokens
            if (child_type == "set") {
                condition = get_token_metadata(child_id, "condition")
                if (condition ~ /macro_name/ && DEBUG_ENABLED) {
                    printf "DEBUG evaluate_for: BEFORE clone, child_id=%d type=%s children=%d condition=[%s]\n", child_id, child_type, get_children_count(child_id), condition > "/dev/stderr"
                }
            }
            
            # Clone subtree for this iteration
            cloned_child_id = clone_subtree(child_id)
            if (cloned_child_id > 0) {
                # Debug output for set tokens
                if (child_type == "set") {
                    condition = get_token_metadata(child_id, "condition")
                    if (condition ~ /macro_name/ && DEBUG_ENABLED) {
                        printf "DEBUG evaluate_for: AFTER clone, cloned_child_id=%d type=%s children=%d\n", cloned_child_id, get_token_type(cloned_child_id), get_children_count(cloned_child_id) > "/dev/stderr"
                    }
                }
                # Debug output for if tokens
                if (child_type == "if") {
                    condition = get_token_metadata(child_id, "condition")
                    if (condition ~ /type.*==.*void/ && DEBUG_ENABLED) {
                        printf "DEBUG evaluate_for: BEFORE clone, child_id=%d type=%s children=%d condition=[%s]\n", child_id, child_type, get_children_count(child_id), condition > "/dev/stderr"
                        printf "DEBUG evaluate_for: AFTER clone, cloned_child_id=%d type=%s children=%d\n", cloned_child_id, get_token_type(cloned_child_id), get_children_count(cloned_child_id) > "/dev/stderr"
                    }
                }
                # Evaluate cloned child recursively
                evaluated_child_id = evaluate_token(cloned_child_id)
                evaluated_child_type = get_token_type(evaluated_child_id)
                evaluated_child_children = get_children_count(evaluated_child_id)
                if (child_type == "if") {
                    condition = get_token_metadata(child_id, "condition")
                    if (condition ~ /type.*==.*void/ && DEBUG_ENABLED) {
                        printf "DEBUG evaluate_for: AFTER evaluate_token, evaluated_child_id=%d type=%s children=%d\n", evaluated_child_id, evaluated_child_type, evaluated_child_children > "/dev/stderr"
                    }
                }
                if (child_type == "set" && DEBUG_ENABLED) {
                    printf "DEBUG evaluate_for: iteration %d, set evaluated_child_id=%d type=%s children=%d\n", i, evaluated_child_id, evaluated_child_type, evaluated_child_children > "/dev/stderr"
                }
                if (evaluated_child_id > 0) {
                    add_child(result_token_id, evaluated_child_id)
                    # Debug output (disabled by default - set DEBUG_FOR=1 to enable)
                    # if (ENVIRON["DEBUG_FOR"] == "1") {
                    #     printf "DEBUG evaluate_for: iteration %d, added child_id=%d type=%s children=%d\n", i, evaluated_child_id, get_token_type(evaluated_child_id), get_children_count(evaluated_child_id) > "/dev/stderr"
                    # }
                } else {
                    # Debug output (disabled by default - set DEBUG_FOR=1 to enable)
                    # if (ENVIRON["DEBUG_FOR"] == "1") {
                    #     printf "DEBUG evaluate_for: iteration %d, evaluated_child_id=0 (skipped)\n", i > "/dev/stderr"
                    # }
                }
            }
        }
    }
    
    # Debug output (disabled by default - set DEBUG_FOR=1 to enable)
    # if (ENVIRON["DEBUG_FOR"] == "1") {
    #     printf "DEBUG evaluate_for: FINAL result_token_id=%d type=%s children=%d\n", result_token_id, get_token_type(result_token_id), get_children_count(result_token_id) > "/dev/stderr"
    # }
    
    # Restore old loop variable values if they existed
    for (var_name in old_values) {
        set_var(var_name, old_values[var_name])
        ENVIRON[var_name] = old_values[var_name]
    }
    
    return result_token_id
}

