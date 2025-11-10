# Module for processing for constructs
# Provides function process_for_construct() for iterating over arrays and processing content
# Note: nested_constructs.awk is included by process_template_constructs.awk before this module
# to avoid circular dependency. We use forward declaration pattern - function is called but
# not included here directly.

@include "core/variable_replacer.awk"
@include "constructs/modules/awk_sections.awk"
# Note: nested_constructs.awk is NOT included here to avoid circular dependency
# It will be available via process_template_constructs.awk's include order

# Process for construct: iterate over array and process content for each item
# Parameters:
#   condition - condition expression (item in ARRAY)
#   content - content to process for each item
#   recursion_depth - current recursion depth
# Returns: processed content for all iterations concatenated
function process_for_construct(condition, content, recursion_depth,    item_name, array_name, array_data, items, n, j, processed_content, nested_processed, final_content, old_entry_var, old_entry_env, result, result_lines, result_count, i) {
    result = ""
    result_count = 0
    delete result_lines
    
    # Parse: item in ARRAY
    if (match(condition, /^([^ \t]+)[ \t]+in[ \t]+(.+)$/)) {
        item_var = substr(condition, RSTART, RLENGTH)
        split(item_var, parts, /[ \t]+in[ \t]+/)
        item_name = parts[1]
        gsub(/^[ \t]+|[ \t]+$/, "", item_name)
        array_name = parts[2]
        gsub(/^[ \t]+|[ \t]+$/, "", array_name)
        
        # Check if array exists in ENVIRON (passed from shell)
        if (array_name in ENVIRON) {
            array_data = ENVIRON[array_name]
            # Parse array data (pipe-separated or newline-separated)
            n = split(array_data, items, /\n|\|/)
            for (j = 1; j <= n; j++) {
                if (items[j] != "") {
                    # Save current values if exist
                    old_entry_var = ""
                    old_entry_env = ""
                    if (item_name in vars) {
                        old_entry_var = vars[item_name]
                    }
                    if (item_name in ENVIRON) {
                        old_entry_env = ENVIRON[item_name]
                    }
                    
                    # Set item variable
                    vars[item_name] = items[j]
                    ENVIRON[item_name] = items[j]
                    
                    # Process content with item variable
                    processed_content = content
                    
                    # First, process nested constructs recursively (pass current depth)
                    nested_processed = process_nested_constructs(processed_content, recursion_depth)
                    
                    # Replace variables in processed content using replace_variables function
                    # This handles {{VAR}} and {{VAR|function|args}} patterns with proper safety checks
                    final_content = replace_variables(nested_processed)
                    
                    # Then check if content still contains AWK sections (after nested processing)
                    # Note: AWK sections are processed at the top level in process_template_constructs.awk
                    # after all constructs are processed, so we just accumulate content here
                    # Use array for better performance with large loops
                    result_count++
                    result_lines[result_count] = final_content
                    
                    # Restore ENVIRON and vars
                    if (old_entry_var != "") {
                        vars[item_name] = old_entry_var
                    } else {
                        delete vars[item_name]
                    }
                    if (old_entry_env != "") {
                        ENVIRON[item_name] = old_entry_env
                    } else {
                        delete ENVIRON[item_name]
                    }
                }
            }
        } else if (array_name in arrays) {
            # Array stored in arrays[] (from previous processing)
            # Use same processing logic as ENVIRON arrays for consistency
            n = arrays[array_name, "count"]
            for (j = 1; j <= n; j++) {
                item_value = arrays[array_name, j]
                if (item_value != "") {
                    # Save current values if exist
                    old_entry_var = ""
                    old_entry_env = ""
                    if (item_name in vars) {
                        old_entry_var = vars[item_name]
                    }
                    if (item_name in ENVIRON) {
                        old_entry_env = ENVIRON[item_name]
                    }
                    
                    # Set item variable
                    vars[item_name] = item_value
                    ENVIRON[item_name] = item_value
                    
                    # Process content with item variable
                    processed_content = content
                    
                    # Process nested constructs recursively (pass current depth)
                    nested_processed = process_nested_constructs(processed_content, recursion_depth)
                    
                    # Replace variables in processed content using replace_variables function
                    final_content = replace_variables(nested_processed)
                    
                    # AWK sections are processed at top level, so just accumulate content
                    # Use array for better performance with large loops
                    result_count++
                    result_lines[result_count] = final_content
                    
                    # Restore ENVIRON and vars
                    if (old_entry_var != "") {
                        vars[item_name] = old_entry_var
                    } else {
                        delete vars[item_name]
                    }
                    if (old_entry_env != "") {
                        ENVIRON[item_name] = old_entry_env
                    } else {
                        delete ENVIRON[item_name]
                    }
                }
            }
        }
    }
    
    # Combine result_lines array into result string (more efficient than string concatenation in loop)
    if (result_count > 0) {
        for (i = 1; i <= result_count; i++) {
            result = result result_lines[i]
        }
    }
    
    return result
}

