# Replace template constructs in template file
# Reads constructs file and processed content, replaces markers in template

BEGIN {
    # Read constructs mapping (start_line -> processed_content)
    while ((getline line < constructs_file) > 0) {
        split(line, parts, "|")
        if (length(parts) >= 5) {
            construct_type = parts[1]
            start_line = parts[2]
            end_line = parts[3]
            processed_content = parts[5]
            # Handle multi-line content
            if (length(parts) > 5) {
                for (i = 6; i <= length(parts); i++) {
                    processed_content = processed_content "|" parts[i]
                }
            }
            constructs[start_line] = processed_content
            construct_end[start_line] = end_line
            construct_types[start_line] = construct_type
        }
    }
    close(constructs_file)
    
    # Read processed content
    processed_count = 0
    while ((getline line < processed_file) > 0) {
        processed_count++
        processed_lines[processed_count] = line
    }
    close(processed_file)
    
    # Track which constructs we've output
    processed_idx = 1
    skip_until = 0
}

{
    current_line = NR
    
    # Reset skip_until if we've passed it
    if (current_line > skip_until) {
        skip_until = 0
    }
    
    # Check if we're in a construct that should be replaced
    replaced = 0
    for (start in constructs) {
        if (current_line >= start && current_line <= construct_end[start]) {
            # This line is part of a construct
            construct_type = construct_types[start]
            if (current_line == start) {
                # For "var" constructs, ignore them - they should be processed as regular variables
                # Simple variables like {{BASENAME}} should NOT create construct entries
                # They are processed directly in the variable replacement phase below
                if (construct_type == "var") {
                    # Skip this construct - let it be processed as a regular variable
                    # But we need to skip the processed content from processed_file
                    if (processed_idx <= processed_count) {
                        processed_idx++  # Skip the processed content
                    }
                    skip_until = construct_end[start]
                    replaced = 0  # Don't mark as replaced - let it fall through to variable replacement
                    break
                } else {
                    # For other construct types, output processed content instead
                    if (processed_idx <= processed_count) {
                        print processed_lines[processed_idx]
                        processed_idx++
                    }
                    skip_until = construct_end[start]
                    replaced = 1
                    break
                }
            } else if (current_line <= skip_until && construct_type != "var") {
                # Skip original construct lines (but not var constructs - they're processed as variables)
                replaced = 1
                break
            }
        }
    }
    
    if (!replaced) {
        # Output line as-is, but replace {{VAR}} markers
        output_line = $0
        
        # DEBUG: Track if this is the problematic line
        is_basename_line = (index(output_line, "{{BASENAME}}") > 0 && index(output_line, "#include") > 0)
        
        # Safety check: if output_line already contains repeated pattern at the start, 
        # it means this line has been processed before incorrectly
        # Check for common variable values that might be repeated
        # IMPORTANT: This check must happen BEFORE variable replacement to catch corrupted lines
        # Also check AFTER variable replacement to catch loops during replacement
        # Look for #include to find the actual start of the line
        include_pos = index(output_line, "#include")
        if (include_pos > 0) {
            # Found #include - check if there's a suspiciously long pattern before it
            before_include = substr(output_line, 1, include_pos - 1)
            # If before_include is longer than 50 chars, check if it's a repeated pattern
            if (length(before_include) > 50) {
                # Check if any known variable value is repeated
                # Check all common variable names (BASENAME, etc.)
                pattern_found = 0
                # Check all variables in ENVIRON for repeated patterns
                for (var_name in ENVIRON) {
                    var_val = ENVIRON[var_name]
                    if (length(var_val) > 5 && length(var_val) < 100 && length(before_include) >= length(var_val) * 3) {
                        # Check if before_include starts with var_val repeated
                        repeated_count = 0
                        pos = 1
                        while (pos <= length(before_include) - length(var_val) + 1) {
                            if (substr(before_include, pos, length(var_val)) == var_val) {
                                repeated_count++
                                pos += length(var_val)
                            } else {
                                break
                            }
                        }
                        if (repeated_count >= 3) {
                            # Line starts with repeated pattern - extract from #include
                            output_line = substr(output_line, include_pos)
                            pattern_found = 1
                            break
                        }
                    }
                }
                # If variable check didn't work, try heuristic: if before_include is very long
                # (more than 100 chars), it's likely corrupted - extract from #include
                # Also check if before_include contains no spaces/newlines (indicates repetition)
                if (!pattern_found) {
                    if (length(before_include) > 100) {
                        output_line = substr(output_line, include_pos)
                        pattern_found = 1
                    } else if (length(before_include) > 50) {
                        # Check if before_include has no whitespace (indicates repetition)
                        has_whitespace = match(before_include, /[ \n\t]/)
                        if (has_whitespace == 0) {
                            # No whitespace in before_include - likely a repeated pattern
                            output_line = substr(output_line, include_pos)
                            pattern_found = 1
                        }
                    }
                }
            }
        }
        
        # Replace variable markers {{VAR}} or {{VAR|function|args}}
        # Prevent infinite loop: limit variable replacement iterations
        replacement_iterations = 0
        max_replacements = 1000
        while (match(output_line, /{{[^#\/][^}]*}}/) && replacement_iterations < max_replacements) {
            replacement_iterations++
            
            # Safety check: verify that we have a complete marker (starts with {{ and ends with }})
            marker_start = RSTART
            marker_end = RSTART + RLENGTH - 1
            if (substr(output_line, marker_start, 2) != "{{" || substr(output_line, marker_end - 1, 2) != "}}") {
                # Incomplete marker - remove it and continue
                before = substr(output_line, 1, marker_start - 1)
                after = substr(output_line, marker_end + 1)
                output_line = before after
                continue
            }
            
            var_expr = substr(output_line, RSTART + 2, RLENGTH - 4)
            gsub(/^[ \t]+|[ \t]+$/, "", var_expr)
            
            # Safety check: if var_expr is empty or contains only whitespace, break to prevent infinite loop
            if (var_expr == "" || match(var_expr, /^[ \t]*$/) > 0) {
                # Remove the malformed marker
                before = substr(output_line, 1, RSTART - 1)
                after = substr(output_line, RSTART + RLENGTH)
                output_line = before after
                continue
            }
            
            # Additional safety: if we've already processed many iterations, check for infinite loop
            # This can happen if the replacement creates a new marker that matches again
            if (replacement_iterations > 50) {
                # Likely infinite loop - check if we're replacing the same thing repeatedly
                # If the string is growing very large, we're likely in an infinite loop
                if (length(output_line) > 5000) {
                    # Likely infinite loop - remove the marker and break
                    before = substr(output_line, 1, RSTART - 1)
                    after = substr(output_line, RSTART + RLENGTH)
                    output_line = before after
                    break
                }
            }
            
            # Check if variable has function call: VAR|function|args
            var_value = ""
            if (match(var_expr, /^([^|]+)\|([^|]+)(\|(.+))?$/)) {
                split(var_expr, func_parts, "|")
                var_name = func_parts[1]
                func_name = func_parts[2]
                func_arg = ""
                if (length(func_parts) > 2) {
                    func_arg = func_parts[3]
                }
                
                # Get variable value from ENVIRON
                if (var_name in ENVIRON) {
                    base_value = ENVIRON[var_name]
                    
                    # Apply function
                    if (func_name == "split") {
                        delimiter = func_arg
                        if (delimiter == "pipe" || delimiter == "|") {
                            delimiter = "|"
                        } else if (delimiter == "newline" || delimiter == "\\n") {
                            delimiter = "\n"
                        }
                        n = split(base_value, parts_array, delimiter)
                        # Store parts in ENVIRON for later access
                        for (p = 1; p <= n; p++) {
                            ENVIRON[var_name "_parts_" (p-1)] = parts_array[p]
                        }
                        ENVIRON[var_name "_parts_count"] = n
                        # split function doesn't output anything - it just creates parts
                        var_value = ""
                    } else if (func_name == "part") {
                        # Get part by index
                        index_str = func_arg
                        gsub(/^[ \t]+|[ \t]+$/, "", index_str)
                        index_num = int(index_str)
                        part_var = var_name "_parts_" index_num
                        if (part_var in ENVIRON) {
                            var_value = ENVIRON[part_var]
                        }
                    } else if (func_name == "contains") {
                        # Check if contains substring
                        substring = func_arg
                        if (index(base_value, substring) > 0) {
                            var_value = "1"
                        } else {
                            var_value = "0"
                        }
                    } else if (func_name == "ne") {
                        # Not equal
                        compare_value = func_arg
                        if (base_value != compare_value) {
                            var_value = "1"
                        } else {
                            var_value = "0"
                        }
                    } else if (func_name == "in_list") {
                        # Check if value is in list
                        list_var_name = func_arg
                        gsub(/^[ \t]+|[ \t]+$/, "", list_var_name)
                        list_value = ""
                        if (list_var_name in ENVIRON) {
                            list_value = ENVIRON[list_var_name]
                        }
                        
                        found = 0
                        if (list_value != "" && base_value != "") {
                            n = split(list_value, items, /\n|\|/)
                            for (i = 1; i <= n; i++) {
                                gsub(/^[ \t]+|[ \t]+$/, "", items[i])
                                if (items[i] == base_value) {
                                    found = 1
                                    break
                                }
                            }
                        }
                        var_value = found ? "1" : "0"
                    } else {
                        var_value = base_value
                    }
                }
            } else {
                # Simple variable
                var_name = var_expr
            if (var_name in ENVIRON) {
                var_value = ENVIRON[var_name]
                }
            }
            
                # Replace marker with value
            # Always replace/remove marker, even if var_value is empty (e.g., for split function)
            before = substr(output_line, 1, RSTART - 1)
            after = substr(output_line, RSTART + RLENGTH)
            if (var_value != "") {
                
                # Safety check: if after already contains var_value repeated many times, we're in an infinite loop
                # Check if after starts with var_value repeated (indicating previous replacement created this)
                if (length(after) > length(var_value) * 10 && substr(after, 1, length(var_value)) == var_value) {
                    # Likely infinite loop - check if after contains the same marker
                    after_match_pos = 0
                    after_match_len = 0
                    if (match(after, /{{[^#\/][^}]*}}/)) {
                        # After contains another marker - this is the infinite loop source
                        # Remove the marker from after and break
                        after_match_pos = RSTART
                        after_match_len = RLENGTH
                        after_before = substr(after, 1, after_match_pos - 1)
                        after_after = substr(after, after_match_pos + after_match_len)
                        after = after_before after_after
                        output_line = before var_value after
                        break
                    }
                }
                
                # Additional safety: if before is empty and after contains var_value repeated, we're replacing at the start
                # This can happen if the line starts with the marker and has been processed before
                if (before == "" && length(after) > length(var_value) * 5 && substr(after, 1, length(var_value)) == var_value) {
                    # Likely infinite loop - the line has been processed before and starts with repeated var_value
                    # Find and remove the marker from after, then break
                    if (match(after, /{{[^#\/][^}]*}}/)) {
                        after_match_pos = RSTART
                        after_match_len = RLENGTH
                        after_before = substr(after, 1, after_match_pos - 1)
                        after_after = substr(after, after_match_pos + after_match_len)
                        after = after_before after_after
                        output_line = var_value after
                        break
                    }
                }
                
                # Marker replaced (even if var_value is empty)
                output_line = before var_value after
                
                # DEBUG: Log replacement for BASENAME line
                if (is_basename_line && var_name == "BASENAME") {
                    print "DEBUG: BASENAME replacement - before:", before, "var_value:", var_value, "after:", after > "/dev/stderr"
                    print "DEBUG: output_line after replacement:", output_line > "/dev/stderr"
                    print "DEBUG: length(output_line):", length(output_line) > "/dev/stderr"
                }
                
                # Safety check AFTER replacement: if output_line contains repeated pattern, fix it
                # This check happens after each replacement to catch loops immediately
                # Check for repeated patterns BEFORE checking length to catch early
                include_pos = index(output_line, "#include")
                if (include_pos > 0) {
                    before_include = substr(output_line, 1, include_pos - 1)
                    # DEBUG: Log before_include check for any line with #include
                    if (length(before_include) > 50) {
                        print "DEBUG: After replacement - include_pos:", include_pos, "before_include length:", length(before_include), "content:", substr(before_include, 1, 100) > "/dev/stderr"
                    }
                    # If before_include is longer than 50 chars and has no whitespace, it's likely corrupted
                    if (length(before_include) > 50) {
                        # DEBUG: Log before checking patterns
                        print "DEBUG: Checking patterns - before_include length:", length(before_include), "content:", substr(before_include, 1, 100) > "/dev/stderr"
                        # Check if before_include is a repeated pattern
                        pattern_found = 0
                        # Check all variables in ENVIRON for repeated patterns
                        for (var_name in ENVIRON) {
                            var_val = ENVIRON[var_name]
                            if (length(var_val) > 5 && length(var_val) < 100 && length(before_include) >= length(var_val) * 3) {
                                repeated_count = 0
                                pos = 1
                                while (pos <= length(before_include) - length(var_val) + 1) {
                                    if (substr(before_include, pos, length(var_val)) == var_val) {
                                        repeated_count++
                                        pos += length(var_val)
                                    } else {
                                        break
                                    }
                                }
                                if (repeated_count >= 3) {
                                    # Line contains repeated pattern - extract from #include
                                    output_line = substr(output_line, include_pos)
                                    break  # Stop replacement loop
                                }
                            }
                        }
                        # Heuristic: if before_include is very long (>100 chars) or has no whitespace, it's corrupted
                        if (!pattern_found && length(before_include) > 100) {
                            output_line = substr(output_line, include_pos)
                            break
                        } else if (!pattern_found && length(before_include) > 50) {
                            has_whitespace = match(before_include, /[ \n\t]/)
                            if (has_whitespace == 0) {
                                output_line = substr(output_line, include_pos)
                                break
                            }
                        }
                    }
                }
            } else {
                # Variable not found - remove marker
                before = substr(output_line, 1, RSTART - 1)
                after = substr(output_line, RSTART + RLENGTH)
                output_line = before after
            }
        }
        
        print output_line
    }
}

