# Replace variable markers {{VAR}} and {{VAR|function|args}} in output line
# Uses marker_parser.awk, variable_functions.awk, and safety_checks.awk

@include "core/marker_parser.awk"
@include "core/variable_functions.awk"
@include "core/safety_checks.awk"

# Main function to replace variables in output line
function replace_variables(output_line,    replacement_iterations, max_replacements, marker_start, marker_end, var_expr, parsed_expr, var_name, func_name, func_arg, base_value, var_value, before, after, result) {
    replacement_iterations = 0
    max_replacements = 1000
    
    # Check for repeated patterns BEFORE replacement
    output_line = check_repeated_patterns_before_include(output_line)
    
    # CRITICAL: Restore pipe characters in entire output_line BEFORE matching markers
    # This prevents \003 from being misinterpreted as field separator during parsing
    gsub(/\003/, "|", output_line)
    
    while (match(output_line, /{{[^#\/][^}]*}}/) && replacement_iterations < max_replacements) {
        replacement_iterations++
        
        marker_start = RSTART
        marker_end = RSTART + RLENGTH - 1
        
        # Safety check: incomplete marker
        if (check_incomplete_marker(output_line, marker_start, marker_end)) {
            before = substr(output_line, 1, marker_start - 1)
            after = substr(output_line, marker_end + 1)
            output_line = before after
            continue
        }
        
        var_expr = parse_marker(substr(output_line, marker_start, marker_end - marker_start + 1))
        
        # Safety check: empty var_expr
        if (var_expr == "" || match(var_expr, /^[ \t]*$/) > 0) {
            before = substr(output_line, 1, marker_start - 1)
            after = substr(output_line, marker_end + 1)
            output_line = before after
            continue
        }
        
        # Check for infinite loop
        if (check_infinite_loop_replacement(output_line, replacement_iterations)) {
            before = substr(output_line, 1, marker_start - 1)
            after = substr(output_line, marker_end + 1)
            output_line = before after
            break
        }
        
        # Parse variable expression
        parsed_expr = parse_var_expr(var_expr)
        var_name = get_var_name(parsed_expr)
        func_name = get_func_name(parsed_expr)
        func_arg = get_func_arg(parsed_expr)
        
        # Get base value from vars array first, then ENVIRON
        # vars array contains variables set by {{#set}} and for loops
        base_value = ""
        if (var_name in vars) {
            base_value = vars[var_name]
        } else if (var_name in ENVIRON) {
            base_value = ENVIRON[var_name]
        }
        
        # Process function if present
        if (func_name != "") {
            var_value = process_variable_function(var_name, func_name, func_arg, base_value)
        } else {
            var_value = base_value
        }
        
        # Replace marker
        before = substr(output_line, 1, marker_start - 1)
        after = substr(output_line, marker_end + 1)
        
        # Safety checks before replacement
        if (check_repeated_value_in_after(after, var_value)) {
            # Remove marker from after
            if (match(after, /{{[^#\/][^}]*}}/)) {
                after_match_pos = RSTART
                after_match_len = RLENGTH
                after_before = substr(after, 1, after_match_pos - 1)
                after_after = substr(after, after_match_pos + after_match_len)
                after = after_before after_after
            }
            output_line = before var_value after
            break
        }
        
        if (check_empty_before_repeated_after(before, after, var_value)) {
            # Remove marker from after
            if (match(after, /{{[^#\/][^}]*}}/)) {
                after_match_pos = RSTART
                after_match_len = RLENGTH
                after_before = substr(after, 1, after_match_pos - 1)
                after_after = substr(after, after_match_pos + after_match_len)
                after = after_before after_after
            }
            output_line = var_value after
            break
        }
        
        # Replace marker with value (or remove if empty)
        if (var_value != "") {
            output_line = before var_value after
        } else {
            output_line = before after
        }
        
        # Safety check AFTER replacement
        output_line = check_repeated_patterns_before_include(output_line)
    }
    
    return output_line
}

