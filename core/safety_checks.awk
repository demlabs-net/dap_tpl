# Safety checks for template processing
# Detects and prevents infinite loops, repeated patterns, and corrupted lines

# Check for repeated patterns before #include marker
function check_repeated_patterns_before_include(output_line,    include_pos, before_include, var_name, var_val, repeated_count, pos, pattern_found) {
    include_pos = index(output_line, "#include")
    if (include_pos > 0) {
        before_include = substr(output_line, 1, include_pos - 1)
        if (length(before_include) > 50) {
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
                        return substr(output_line, include_pos)
                    }
                }
            }
            # Heuristic: if before_include is very long (>100 chars) or has no whitespace, it's corrupted
            if (length(before_include) > 100) {
                return substr(output_line, include_pos)
            } else if (length(before_include) > 50) {
                has_whitespace = match(before_include, /[ \n\t]/)
                if (has_whitespace == 0) {
                    return substr(output_line, include_pos)
                }
            }
        }
    }
    return output_line
}

# Check for infinite loop in replacement (string growing too large)
function check_infinite_loop_replacement(output_line, replacement_iterations,    max_length) {
    max_length = 5000
    if (replacement_iterations > 50 && length(output_line) > max_length) {
        return 1  # Likely infinite loop
    }
    return 0
}

# Check for incomplete marker
function check_incomplete_marker(marker_text, marker_start, marker_end) {
    if (substr(marker_text, marker_start, 2) != "{{" || substr(marker_text, marker_end - 1, 2) != "}}") {
        return 1  # Incomplete marker
    }
    return 0
}

# Check if after part contains repeated var_value (indicating infinite loop)
function check_repeated_value_in_after(after, var_value,    after_match_pos) {
    if (length(after) > length(var_value) * 10 && substr(after, 1, length(var_value)) == var_value) {
        # Check if after contains another marker
        if (match(after, /{{[^#\/][^}]*}}/)) {
            return 1  # Likely infinite loop
        }
    }
    return 0
}

# Check if before is empty and after contains repeated var_value
function check_empty_before_repeated_after(before, after, var_value) {
    if (before == "" && length(after) > length(var_value) * 5 && substr(after, 1, length(var_value)) == var_value) {
        if (match(after, /{{[^#\/][^}]*}}/)) {
            return 1  # Likely infinite loop
        }
    }
    return 0
}

