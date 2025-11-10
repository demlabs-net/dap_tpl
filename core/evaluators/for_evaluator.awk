# For Evaluator
# Evaluates for loops: {{#for item in ARRAY}}...{{/for}}

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/evaluator.awk"

# Evaluate for token
# Parameters:
#   token_id - for token ID
# Returns: evaluated token ID with loop iterations expanded
function evaluate_for(token_id,    condition, loop_var, array_name, array_value, items, item_count, i, item, result_token_id, child_count, j, child_id, cloned_child_id, metadata, old_value) {
    condition = get_token_metadata(token_id, "condition")
    if (condition == "") {
        return token_id
    }
    
    # Parse condition: "item in ARRAY"
    if (match(condition, /^([^ \t]+)[ \t]+in[ \t]+(.+)$/)) {
        # Extract loop variable and array name
        split(condition, parts, /[ \t]+in[ \t]+/)
        loop_var = parts[1]
        gsub(/^[ \t]+|[ \t]+$/, "", loop_var)
        array_name = parts[2]
        gsub(/^[ \t]+|[ \t]+$/, "", array_name)
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
    
    # Split array into items (newline or pipe separated, preserve pipe characters within entries when using newline)
    # Support both newline-separated (for file-based data) and pipe-separated (for environment variables)
    # Check if array contains newlines - if yes, use newline separator, otherwise use pipe
    if (array_value ~ /\n/) {
        # Newline-separated array (file-based data)
        item_count = split(array_value, items, /\n/)
    } else {
        # Pipe-separated array (environment variable like "item1|item2|item3")
        item_count = split(array_value, items, /\|/)
    }
    
    # Create result token
    delete metadata
    result_token_id = create_token("root", "", metadata)
    
    # Save old value of loop variable if exists
    old_value = get_var(loop_var)
    
    # Push context for loop variable
    push_context()
    
    # Iterate over items
    for (i = 1; i <= item_count; i++) {
        item = items[i]
        gsub(/^[ \t]+|[ \t]+$/, "", item)
        
        if (item == "") {
            continue
        }
        
        # Set loop variable in current context
        set_var(loop_var, item)
        
        # Also set in ENVIRON for compatibility
        ENVIRON[loop_var] = item
        
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
    
    # Restore old value if existed
    if (old_value != "") {
        set_var(loop_var, old_value)
        ENVIRON[loop_var] = old_value
    } else {
        # Remove variable if it didn't exist before
        if (has_var(loop_var)) {
            # Variable was set in parent context, keep it
        } else {
            # Remove from ENVIRON if it was created in loop
            delete ENVIRON[loop_var]
        }
    }
    
    return result_token_id
}
