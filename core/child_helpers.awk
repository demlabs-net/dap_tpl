# Child Helpers
# Helper functions for working with token children

@include "core/token_tree.awk"

# Copy children from source to dest, excluding specified types
# Parameters:
#   source_id - source token ID
#   dest_id - destination token ID
#   exclude_types - space-separated string of types to exclude (e.g., "elif else")
function copy_children_except(source_id, dest_id, exclude_types,    child_count, i, child_id, child_type, exclude_arr, exclude_count, j, should_exclude) {
    child_count = get_children_count(source_id)
    if (child_count == 0) {
        return
    }
    
    # Parse exclude_types into array
    exclude_count = split(exclude_types, exclude_arr, /[ \t]+/)
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(source_id, i)
        child_type = get_token_type(child_id)
        
        # Check if this type should be excluded
        should_exclude = 0
        for (j = 1; j <= exclude_count; j++) {
            if (child_type == exclude_arr[j]) {
                should_exclude = 1
                break
            }
        }
        
        if (!should_exclude) {
            add_child(dest_id, child_id)
        }
    }
}

# Get all children of specified type
# Parameters:
#   token_id - token ID
#   type - child type to filter
#   result_array - output array (will be indexed 1..N)
# Returns: count of matching children
# NODISPATCH: takes array parameter
function get_children_by_type(token_id, type, result_array,    child_count, i, child_id, child_type, count) {
    delete result_array
    child_count = get_children_count(token_id)
    count = 0
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        child_type = get_token_type(child_id)
        if (child_type == type) {
            count++
            result_array[count] = child_id
        }
    }
    
    return count
}

