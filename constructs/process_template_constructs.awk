# Process template constructs: evaluate conditions, execute loops, set variables
# Input format: type|start_line|end_line|condition/var/script|content
# Output: processed content with constructs evaluated

# Include order is critical to avoid circular dependencies:
# 1. Core modules first (no dependencies)
# 2. if_construct.awk (no dependencies on other constructs)
# 3. for_construct.awk (needs variable_replacer, but NOT nested_constructs yet)
# 4. nested_constructs.awk (can now use both if_construct and for_construct)
# 5. Other modules
@include "core/variable_functions.awk"
@include "core/variable_replacer.awk"
@include "constructs/modules/if_construct.awk"
@include "constructs/modules/for_construct.awk"
@include "constructs/modules/nested_constructs.awk"
@include "constructs/modules/awk_sections.awk"

BEGIN {
    # Initialize variable storage
    # Global variable storage:
    #   vars[var_name] - local variables set via {{#set VAR=value}} or for loops
    #   arrays[array_name, "count"] - array element count (for arrays stored in arrays[])
    #   arrays[array_name, index] - array elements (index starts at 1)
    #   ENVIRON[var_name] - environment variables from shell (passed via export)
    delete vars
    delete arrays
    delete array_items
    
    # Get recursion depth from environment (set by parent process to prevent infinite recursion)
    recursion_depth = ENVIRON["DAP_TPL_RECURSION_DEPTH"]
    if (recursion_depth == "") recursion_depth = 0
    
    # Read all constructs first
    construct_count = 0
    while ((getline line) > 0) {
        construct_count++
        split(line, parts, "|")
        if (length(parts) >= 5) {
            constructs[construct_count, "type"] = parts[1]
            constructs[construct_count, "start"] = parts[2]
            constructs[construct_count, "end"] = parts[3]
            constructs[construct_count, "condition"] = parts[4]
            constructs[construct_count, "content"] = parts[5]
            # Handle multi-line content (if there are more parts)
            # Content is pipe-separated, need to join with newlines
            if (length(parts) > 5) {
                for (i = 6; i <= length(parts); i++) {
                    constructs[construct_count, "content"] = constructs[construct_count, "content"] "\n" parts[i]
                }
            }
            # Restore newlines from special marker (\001 -> \n)
            # Use gsub with proper escaping to ensure all markers are replaced
            gsub(/\001/, "\n", constructs[construct_count, "content"])
            # Ensure content is properly formatted - no broken lines
            # This fixes issues where || operators might be split across lines
        }
    }
    
    # Process constructs
    for (i = 1; i <= construct_count; i++) {
        type = constructs[i, "type"]
        condition = constructs[i, "condition"]
        content = constructs[i, "content"]
        
        if (type == "set") {
            # {{#set VAR=value}} or {{#set VAR={{VAR2|function|args}}}}
            if (match(condition, /^([^=]+)=(.*)$/)) {
                var_name = substr(condition, RSTART, RLENGTH)
                split(var_name, parts, "=")
                var_name = parts[1]
                gsub(/^[ \t]+|[ \t]+$/, "", var_name)
                var_value_expr = substr(condition, RSTART + length(parts[1]) + 1)
                gsub(/^[ \t]+|[ \t]+$/, "", var_value_expr)
                
                # Check if value expression contains function call
                var_value = ""
                if (match(var_value_expr, /^{{([^}]+)}}$/)) {
                    # Extract inner expression
                    inner_expr = substr(var_value_expr, 3, length(var_value_expr) - 4)
                    gsub(/^[ \t]+|[ \t]+$/, "", inner_expr)
                    
                    # Check if it's a function call
                    if (match(inner_expr, /^([^|]+)\|([^|]+)(\|(.+))?$/)) {
                        split(inner_expr, func_parts, "|")
                        source_var = func_parts[1]
                        func_name = func_parts[2]
                        func_arg = ""
                        if (length(func_parts) > 2) {
                            func_arg = func_parts[3]
                        }
                        
                        # Get source variable value
                        source_value = ""
                        if (source_var in vars) {
                            source_value = vars[source_var]
                        } else if (source_var in ENVIRON) {
                            source_value = ENVIRON[source_var]
                        }
                        
                        # Apply function
                        if (func_name == "split") {
                            delimiter = func_arg
                            if (delimiter == "pipe" || delimiter == "|") {
                                delimiter = "|"
                            } else if (delimiter == "newline" || delimiter == "\n") {
                                delimiter = "\n"
                            }
                            n = split(source_value, parts_array, delimiter)
                            for (p = 1; p <= n; p++) {
                                vars[source_var "_parts_" (p-1)] = parts_array[p]
                            }
                            vars[source_var "_parts_count"] = n
                            # split function doesn't output anything - it just creates parts
                            var_value = ""
                        } else if (func_name == "part") {
                            index_str = func_arg
                            gsub(/^[ \t]+|[ \t]+$/, "", index_str)
                            index_num = int(index_str)
                            part_var = source_var "_parts_" index_num
                            if (part_var in vars) {
                                var_value = vars[part_var]
                            } else if (part_var in ENVIRON) {
                                var_value = ENVIRON[part_var]
                            }
                        } else if (func_name == "contains") {
                            substring = func_arg
                            if (index(source_value, substring) > 0) {
                                var_value = "1"
                            } else {
                                var_value = "0"
                            }
                        } else if (func_name == "ne") {
                            compare_value = func_arg
                            if (source_value != compare_value) {
                                var_value = "1"
                            } else {
                                var_value = "0"
                            }
                        } else {
                            var_value = source_value
                        }
                    } else {
                        # Simple variable reference
                        if (inner_expr in vars) {
                            var_value = vars[inner_expr]
                        } else if (inner_expr in ENVIRON) {
                            var_value = ENVIRON[inner_expr]
                        }
                    }
                } else {
                    # Simple literal value
                    var_value = var_value_expr
                }
                
                if (var_value != "") {
                vars[var_name] = var_value
                }
            }
        } else if (type == "if") {
            # {{#if VAR}} or {{#if VAR|function|args}}...{{/if}}
            condition_expr = condition
            else_content = ""
            if (i < construct_count && constructs[i+1, "type"] == "else") {
                else_content = constructs[i+1, "content"]
                i++  # Skip else construct
            }
            
            # Process nested constructs in content first
            processed_content = process_nested_constructs(content, recursion_depth)
            if (else_content != "") {
                else_content = process_nested_constructs(else_content, recursion_depth)
            }
            
            # Evaluate condition and get result
            result_content = process_if_construct(condition_expr, processed_content, else_content, recursion_depth)
            
            if (result_content != "") {
                # Check if content contains AWK sections that need to be processed
                if (result_content ~ /{{AWK:/) {
                    # Process AWK sections in content
                    process_awk_sections_in_content(result_content)
                } else {
                    print result_content
                }
            }
        } else if (type == "for") {
            # {{#for item in ARRAY}}...{{/for}}
            # Use for_construct module to process loop
            result_content = process_for_construct(condition, content, recursion_depth)
            if (result_content != "") {
                print result_content
            }
        } else if (type == "var") {
            # {{VAR}} or {{VAR|function|args}} - output variable with optional function
            var_expr = condition
            gsub(/^[ \t]+|[ \t]+$/, "", var_expr)
            
            # Check if variable has function call: VAR|function|args
            if (match(var_expr, /^([^|]+)\|([^|]+)(\|(.+))?$/)) {
                var_name = substr(var_expr, RSTART, RLENGTH)
                split(var_expr, func_parts, "|")
                var_name = func_parts[1]
                func_name = func_parts[2]
                func_arg = ""
                if (length(func_parts) > 2) {
                    func_arg = func_parts[3]
                }
                
                # Get variable value
                var_value = ""
                if (var_name in vars) {
                    var_value = vars[var_name]
                } else if (var_name in ENVIRON) {
                    var_value = ENVIRON[var_name]
                }
                
                # Apply function
                result = ""
                if (func_name == "split") {
                    # Split variable by delimiter (pipe, newline, etc.)
                    delimiter = func_arg
                    if (delimiter == "pipe" || delimiter == "|") {
                        delimiter = "|"
                    } else if (delimiter == "newline" || delimiter == "\n") {
                        delimiter = "\n"
                    }
                    n = split(var_value, parts_array, delimiter)
                    # Store parts in vars as var_name_parts_0, var_name_parts_1, etc.
                    for (p = 1; p <= n; p++) {
                        vars[var_name "_parts_" (p-1)] = parts_array[p]
                    }
                    vars[var_name "_parts_count"] = n
                    # split function doesn't output anything - it just creates parts
                    result = ""
                } else if (func_name == "part") {
                    # Get part by index: VAR|part|index
                    index_str = func_arg
                    gsub(/^[ \t]+|[ \t]+$/, "", index_str)
                    index_num = int(index_str)
                    part_var = var_name "_parts_" index_num
                    if (part_var in vars) {
                        result = vars[part_var]
                    }
                } else if (func_name == "contains") {
                    # Check if variable contains substring: VAR|contains|substring
                    substring = func_arg
                    if (index(var_value, substring) > 0) {
                        result = "1"
                    } else {
                        result = "0"
                    }
                } else if (func_name == "ne") {
                    # Not equal: VAR|ne|value
                    compare_value = func_arg
                    if (var_value != compare_value) {
                        result = "1"
                    } else {
                        result = "0"
                    }
                } else if (func_name == "in_list") {
                    # Check if variable value is in list: VAR|in_list|LIST_VAR
                    list_var_name = func_arg
                    gsub(/^[ \t]+|[ \t]+$/, "", list_var_name)
                    list_value = ""
                    if (list_var_name in vars) {
                        list_value = vars[list_var_name]
                    } else if (list_var_name in ENVIRON) {
                        list_value = ENVIRON[list_var_name]
                    }
                    
                    # Check if var_value is in list_value (newline or pipe separated)
                    found = 0
                    if (list_value != "" && var_value != "") {
                        n = split(list_value, items, /\n|\|/)
                        for (i = 1; i <= n; i++) {
                            gsub(/^[ \t]+|[ \t]+$/, "", items[i])
                            if (items[i] == var_value) {
                                found = 1
                                break
                            }
                        }
                    }
                    result = found ? "1" : "0"
                } else {
                    # Unknown function - return original value
                    result = var_value
                }
                
                if (result != "") {
                    print result
                }
            } else {
                # Simple variable output
                var_name = var_expr
            if (var_name in vars) {
                print vars[var_name]
            } else if (var_name in ENVIRON) {
                print ENVIRON[var_name]
                }
            }
        } else if (type == "include") {
            # {{#include FILE}} - include file content
            file_path = condition
            gsub(/^[ \t]+|[ \t]+$/, "", file_path)
            
            # Check if file_path is a variable name (not a path)
            # First check vars, then ENVIRON
            if (file_path in vars) {
                file_path = vars[file_path]
            } else if (file_path in ENVIRON) {
                file_path = ENVIRON[file_path]
            }
            
            # Check if file exists and is not empty/placeholder
            if (file_path != "" && file_path != "{{" file_path "}}") {
                # Read and output file content
                file_found = 0
                while ((getline line < file_path) > 0) {
                    print line
                    file_found = 1
                }
                close(file_path)
                # If file was empty or doesn't exist, do nothing (silent fail)
            }
        } else if (type == "awk") {
            # {{#awk:...}} - inline AWK script
            # Execute AWK script
            script = condition
            # Create temp file for script
            script_file = "/tmp/template_awk_" NR "_" rand() ".awk"
            print script > script_file
            close(script_file)
            
            # Execute script
            cmd = "gawk -f " script_file " 2>&1"
            while ((cmd | getline line) > 0) {
                print line
            }
            close(cmd)
            system("rm -f " script_file)
        } else if (type == "else") {
            # Else block - already handled in if processing
            # Do nothing here
        } else {
            # Unknown type - output as-is
            print content
        }
    }
}

