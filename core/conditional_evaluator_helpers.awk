# Conditional Evaluator Helpers
# Helper functions for evaluating conditional constructs with branches
# Simplifies the common pattern of if/elif/else evaluation

@include "core/token_tree.awk"
@include "core/child_helpers.awk"
@include "core/metadata_helpers.awk"

# Copy main branch children (excluding branch markers) to result
# Parameters:
#   source_token_id - source token (e.g., if token)
#   result_token_id - result token to add children to
#   exclude_types - space-separated list of branch types to exclude (e.g., "elif else")
function copy_main_branch_children(source_token_id, result_token_id, exclude_types,    child_count, i, child_id, child_type, exclude_arr, exclude_count, j, should_exclude) {
    child_count = get_children_count(source_token_id)
    if (child_count == 0) {
        return
    }
    
    # Parse exclude_types into array
    exclude_count = split(exclude_types, exclude_arr, /[ \t]+/)
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(source_token_id, i)
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
            add_child(result_token_id, child_id)
        }
    }
}

# Copy branch children to result
# Parameters:
#   branch_token_id - branch token (elif or else)
#   result_token_id - result token to add children to
function copy_branch_children(branch_token_id, result_token_id,    branch_child_count, i, branch_child_id) {
    branch_child_count = get_children_count(branch_token_id)
    for (i = 1; i <= branch_child_count; i++) {
        branch_child_id = get_child(branch_token_id, i)
        add_child(result_token_id, branch_child_id)
    }
}

