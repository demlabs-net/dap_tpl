# Conditional Evaluator Helpers
# Helper functions for evaluating conditional constructs with branches
# Simplifies the common pattern of if/elif/else evaluation
# Note: DEBUG_FILE_NAME is automatically set by build_engine.sh

@include "core/token_tree.awk"
@include "core/child_helpers.awk"
@include "core/metadata_helpers.awk"
@include "core/debug.awk"

# Copy main branch children (excluding branch markers) to result
# Parameters:
#   source_token_id - source token (e.g., if token)
#   result_token_id - result token to add children to
#   exclude_types - space-separated list of branch types to exclude (e.g., "elif else")
function copy_main_branch_children(source_token_id, result_token_id, exclude_types,    child_count, i, child_id, child_type, exclude_arr, exclude_count, j, should_exclude, source_condition) {
    child_count = get_children_count(source_token_id)
    
    # Debug output
    source_condition = get_token_metadata(source_token_id, "condition")
    if (source_condition ~ /type.*==.*void/) {
        if (DEBUG_ENABLED) {
            printf "DEBUG copy_main_branch_children: source_token_id=%d child_count=%d exclude_types=[%s]\n", source_token_id, child_count, exclude_types > "/dev/stderr"
        }
        log_debug("copy_main_branch_children: source_token_id=%d child_count=%d exclude_types=[%s]", source_token_id, child_count, exclude_types)
    }
    
    if (child_count == 0) {
        if (source_condition ~ /type.*==.*void/) {
            if (DEBUG_ENABLED) {
                printf "DEBUG copy_main_branch_children: NO CHILDREN!\n" > "/dev/stderr"
            }
        }
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
            # Debug output
            if (source_condition ~ /type.*==.*void/) {
                if (DEBUG_ENABLED) {
                    printf "DEBUG copy_main_branch_children: adding child id=%d type=%s\n", child_id, child_type > "/dev/stderr"
                }
                log_debug("copy_main_branch_children: adding child id=%d type=%s", child_id, child_type)
            }
            add_child(result_token_id, child_id)
        } else {
            if (source_condition ~ /type.*==.*void/) {
                if (DEBUG_ENABLED) {
                    printf "DEBUG copy_main_branch_children: EXCLUDING child id=%d type=%s\n", child_id, child_type > "/dev/stderr"
                }
            }
        }
    }
    
    # Debug output
    if (source_condition ~ /type.*==.*void/) {
        result_children = get_children_count(result_token_id)
        if (DEBUG_ENABLED) {
            printf "DEBUG copy_main_branch_children: result_token_id=%d result_children=%d\n", result_token_id, result_children > "/dev/stderr"
        }
        log_debug("copy_main_branch_children: result_token_id=%d result_children=%d", result_token_id, result_children)
    }
}

# Copy branch children to result
# Parameters:
#   branch_token_id - branch token (elif or else)
#   result_token_id - result token to add children to
function copy_branch_children(branch_token_id, result_token_id,    branch_child_count, i, branch_child_id, parent_condition) {
    branch_child_count = get_children_count(branch_token_id)
    
    # Debug output - try to get condition from parent or check if this is else branch
    # For else branches, we need to check differently
    parent_condition = ""
    # Try to get condition from a parent if token if result_token_id has metadata
    if (get_token_metadata(result_token_id, "condition") != "") {
        parent_condition = get_token_metadata(result_token_id, "condition")
    }
    
    if (DEBUG_ENABLED) {
        printf "DEBUG copy_branch_children: branch_token_id=%d branch_child_count=%d branch_type=%s\n", branch_token_id, branch_child_count, get_token_type(branch_token_id) > "/dev/stderr"
    }
    
    if (parent_condition ~ /type.*==.*void/ || get_token_type(branch_token_id) == "else") {
        log_debug("copy_branch_children: branch_token_id=%d branch_child_count=%d", branch_token_id, branch_child_count)
    }
    
    for (i = 1; i <= branch_child_count; i++) {
        branch_child_id = get_child(branch_token_id, i)
        
        # Debug output
        if (DEBUG_ENABLED) {
            printf "DEBUG copy_branch_children: adding child id=%d type=%s\n", branch_child_id, get_token_type(branch_child_id) > "/dev/stderr"
        }
        if (parent_condition ~ /type.*==.*void/ || get_token_type(branch_token_id) == "else") {
            log_debug("copy_branch_children: adding child id=%d type=%s", branch_child_id, get_token_type(branch_child_id))
        }
        
        add_child(result_token_id, branch_child_id)
    }
    
    # Debug output
    result_children = get_children_count(result_token_id)
    if (DEBUG_ENABLED) {
        printf "DEBUG copy_branch_children: result_token_id=%d result_children=%d\n", result_token_id, result_children > "/dev/stderr"
    }
    if (parent_condition ~ /type.*==.*void/ || get_token_type(branch_token_id) == "else") {
        log_debug("copy_branch_children: result_token_id=%d result_children=%d", result_token_id, result_children)
    }
}

