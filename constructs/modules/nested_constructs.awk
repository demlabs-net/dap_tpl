# Module for processing nested template constructs
# Provides function process_nested_constructs() for recursive construct processing

@include "constructs/parse_constructs_lib.awk"
@include "core/variable_functions.awk"
@include "constructs/modules/if_construct.awk"
# Note: for_construct.awk is included conditionally to avoid circular dependency
# It will be included by process_template_constructs.awk before nested_constructs.awk

# Function to recursively process nested template constructs in content
# Processes constructs directly in current process without spawning new AWK processes
# This prevents infinite recursion that occurs when process_nested_constructs spawns
# a new AWK process which calls process_nested_constructs again
function process_nested_constructs(content_text, depth,    temp_file, constructs_file, scripts_dir, nested_constructs, nested_count, i, parts, result, processed_content, content_lines, n_content_lines) {
    # Initialize depth if not provided
    if (depth == "") depth = 0
    
    # Prevent infinite recursion - max depth is 10
    if (depth > 10) {
        print "ERROR: Maximum recursion depth exceeded in process_nested_constructs" > "/dev/stderr"
        return content_text
    }
    
    # Check if content contains template constructs
    if (content_text !~ /{{#(if|for|set|awk)/) {
        return content_text
    }
    
    # Parse constructs using parse_constructs_lib function
    scripts_dir = ENVIRON["SCRIPTS_DIR"]
    if (scripts_dir == "") scripts_dir = "."
    
    # Split content into lines for parsing
    n_content_lines = split(content_text, content_lines, "\n")
    
    # Parse constructs using library function
    nested_count = parse_constructs_from_array(content_lines, n_content_lines, nested_constructs)
    
    # Process nested constructs using same logic as main processing loop
    # But without spawning new AWK process - this prevents infinite recursion
    result = ""
    for (i = 1; i <= nested_count; i++) {
        nested_type = nested_constructs[i, "type"]
        nested_condition = nested_constructs[i, "condition"]
        nested_content = nested_constructs[i, "content"]
        
        if (nested_type == "if") {
            # Check for else construct after if
            nested_else_content = ""
            if (i < nested_count && nested_constructs[i + 1, "type"] == "else") {
                nested_else_content = nested_constructs[i + 1, "content"]
                i++  # Skip else construct
            }
            
            # Process nested content and else content recursively
            processed_content = process_nested_constructs(nested_content, depth + 1)
            if (nested_else_content != "") {
                nested_else_content = process_nested_constructs(nested_else_content, depth + 1)
            }
            
            # Use if_construct module to process if construct with else support
            result_content = process_if_construct(nested_condition, processed_content, nested_else_content, depth + 1)
            if (result_content != "") {
                result = result result_content
            }
        } else if (nested_type == "for") {
            # Use for_construct module to process for construct
            result_content = process_for_construct(nested_condition, nested_content, depth + 1)
            if (result_content != "") {
                result = result result_content
            }
        } else if (nested_type == "set") {
            # Process set - extract variable assignment
            if (match(nested_condition, /^([^=]+)=(.*)$/)) {
                var_name = substr(nested_condition, RSTART, RLENGTH)
                split(var_name, var_parts, "=")
                var_name = var_parts[1]
                gsub(/^[ \t]+|[ \t]+$/, "", var_name)
                var_value = var_parts[2]
                gsub(/^[ \t]+|[ \t]+$/, "", var_value)
                # Process variable value (may contain template constructs)
                var_value = process_nested_constructs(var_value, depth + 1)
                vars[var_name] = var_value
                ENVIRON[var_name] = var_value
            }
        } else {
            # Other types - just append content
            result = result nested_content
        }
    }
    
    # After processing constructs, process remaining variables (including function calls)
    result = process_variables_in_content(result)
    
    return result
}

# Helper function to process variables in content (including function calls)
function process_variables_in_content(content_text,    processed_result, changed, before, marker_content, after, replacement_iterations, max_replacements, var_expr, var_value, var_expr_restored, func_parts, var_name_func, func_name, func_arg, source_value, delimiter, n, parts_array, p, index_str, index_num, part_var, list_var_name, list_value, found, items, i) {
    # First, normalize newlines inside {{...}} markers to allow multiline variable expressions
    processed_result = content_text
    changed = 1
    while (changed) {
        changed = 0
        if (match(processed_result, /{{[^}]*\n[^}]*}}/)) {
            before = substr(processed_result, 1, RSTART - 1)
            marker_content = substr(processed_result, RSTART, RLENGTH)
            after = substr(processed_result, RSTART + RLENGTH)
            gsub(/\n/, "\002", marker_content)  # Use \002 as temporary newline marker
            processed_result = before marker_content after
            changed = 1
        }
    }
    
    if (processed_result ~ /{{[^#\/][^}]*}}/) {
        replacement_iterations = 0
        max_replacements = 1000
        while (match(processed_result, /{{[^#\/][^}]*}}/) && replacement_iterations < max_replacements) {
            replacement_iterations++
            var_expr = substr(processed_result, RSTART + 2, RLENGTH - 4)
            gsub(/^[ \t]+|[ \t]+$/, "", var_expr)
            
            var_value = ""
            # Check if it's a function call
            # Restore | from \002 for parsing
            var_expr_restored = var_expr
            gsub(/\002/, "|", var_expr_restored)
            if (match(var_expr_restored, /\|/)) {
                split(var_expr_restored, func_parts, "|")
                var_name_func = func_parts[1]
                gsub(/^[ \t]+|[ \t]+$/, "", var_name_func)
                func_name = func_parts[2]
                gsub(/^[ \t]+|[ \t]+$/, "", func_name)
                func_arg = ""
                if (length(func_parts) > 2) {
                    func_arg = func_parts[3]
                    gsub(/^[ \t]+|[ \t]+$/, "", func_arg)
                }
                
                # Get variable value
                source_value = ""
                if (var_name_func in vars) {
                    source_value = vars[var_name_func]
                } else if (var_name_func in ENVIRON) {
                    source_value = ENVIRON[var_name_func]
                }
                
                # Apply function using variable_functions module
                var_value = process_variable_function(var_name_func, func_name, func_arg, source_value)
            } else {
                # Simple variable
                if (var_expr in vars) {
                    var_value = vars[var_expr]
                } else if (var_expr in ENVIRON) {
                    var_value = ENVIRON[var_expr]
                }
            }
            
            # Replace marker
            if (var_value != "") {
                before = substr(processed_result, 1, RSTART - 1)
                after = substr(processed_result, RSTART + RLENGTH)
                processed_result = before var_value after
            } else {
                # Remove empty variable marker
                before = substr(processed_result, 1, RSTART - 1)
                after = substr(processed_result, RSTART + RLENGTH)
                processed_result = before after
            }
        }
        # Restore newlines from temporary marker
        gsub(/\002/, "\n", processed_result)
    }
    
    return processed_result
}

