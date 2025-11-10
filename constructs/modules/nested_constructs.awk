# Module for processing nested template constructs
# Provides function process_nested_constructs() for recursive construct processing

@include "constructs/parse_constructs_lib.awk"
@include "core/variable_functions.awk"
@include "core/variable_replacer.awk"
@include "constructs/modules/if_construct.awk"
# Note: for_construct.awk is included conditionally to avoid circular dependency
# It will be included by process_template_constructs.awk before nested_constructs.awk

# Function to recursively process nested template constructs in content
# Processes constructs directly in current process without spawning new AWK processes
# This prevents infinite recursion that occurs when process_nested_constructs spawns
# a new AWK process which calls process_nested_constructs again
function process_nested_constructs(content_text, depth,    nested_constructs, nested_count, content_lines, n_content_lines, result, i, nested_type, nested_condition, nested_content, nested_start_str, nested_end_str, nested_start, nested_end, last_end_line, text_before, text_after, k, processed_content, nested_else_content, result_content, processed_nested, var_name, var_parts, var_value) {
    # Initialize depth if not provided
    if (depth == "") depth = 0
    
    # Prevent infinite recursion - max depth is 10
    if (depth > 10) {
        print "ERROR: Maximum recursion depth exceeded in process_nested_constructs" > "/dev/stderr"
        return content_text
    }
    
    # Debug: check content if DAP_TPL_DEBUG is set
    if ("DAP_TPL_DEBUG" in ENVIRON && ENVIRON["DAP_TPL_DEBUG"] == "1") {
        if (content_text ~ /NORMALIZATION_MACROS_DATA|TYPE_TO_SELECT_DATA|BASIC_TYPES_DATA/) {
            print "DEBUG: process_nested_constructs called with content length=" length(content_text) ", depth=" depth > "/dev/stderr"
            if (length(content_text) > 0) {
                print "DEBUG: First 100 chars: " substr(content_text, 1, 100) > "/dev/stderr"
            }
        }
    }
    
    # Check if content contains template constructs
    if (content_text !~ /{{#(if|for|set|awk)/) {
        return content_text
    }
    
    # CRITICAL: Do NOT restore pipe characters here - they will be restored in parse_constructs_from_array
    # before writing to temp file. Restoring here would cause pipes to be split incorrectly.
    
    # Split content into lines for parsing
    n_content_lines = split(content_text, content_lines, "\n")
    
    # Parse constructs using library function
    nested_count = parse_constructs_from_array(content_lines, n_content_lines, nested_constructs)
    
    # Debug: check nested_count if DAP_TPL_DEBUG is set
    if ("DAP_TPL_DEBUG" in ENVIRON && ENVIRON["DAP_TPL_DEBUG"] == "1") {
        if (content_text ~ /NORMALIZATION_MACROS_DATA|TYPE_TO_SELECT_DATA|BASIC_TYPES_DATA/) {
            print "DEBUG: parse_constructs_from_array returned nested_count=" nested_count > "/dev/stderr"
            if (nested_count > 0) {
                print "DEBUG: First nested construct: type=" nested_constructs[1, "type"] ", condition=" nested_constructs[1, "condition"] > "/dev/stderr"
            }
        }
    }
    
    # If no constructs were found, return original content
    if (nested_count == 0) {
        return content_text
    }
    
    # Process nested constructs sequentially
    # Build result by processing constructs and preserving text between them
    # Use start/end line numbers from parser to correctly identify text between constructs
    # CRITICAL: Skip constructs that are nested inside other constructs - they'll be processed recursively
    result = ""
    last_end_line = 0
    
    for (i = 1; i <= nested_count; i++) {
        nested_type = nested_constructs[i, "type"]
        nested_condition = nested_constructs[i, "condition"]
        nested_content = nested_constructs[i, "content"]
        nested_start_str = nested_constructs[i, "start"]
        nested_end_str = nested_constructs[i, "end"]
        
        # Convert start/end from string to number (they come as strings from parsing)
        nested_start = nested_start_str + 0
        nested_end = nested_end_str + 0
        
        # Check if this construct is nested inside another construct
        # A construct is nested if its start/end lines are within another construct's range
        is_nested = 0
        for (j = 1; j <= nested_count; j++) {
            if (j == i) continue  # Skip self
            check_start = nested_constructs[j, "start"] + 0
            check_end = nested_constructs[j, "end"] + 0
            # This construct is nested if it's completely inside another construct
            if (nested_start >= check_start && nested_end <= check_end) {
                is_nested = 1
                break
            }
        }
        
        # Skip nested constructs - they'll be processed recursively by their parent
        if (is_nested) {
            continue
        }
        
        # Add text before this construct (if any)
        # Text between previous construct and this one
        # CRITICAL: Process variables with functions (like {{entry|split|pipe}}) BEFORE
        # processing constructs, so that parts are available for functions like {{entry|part|0}}
        # in {{#set}} constructs. Other variables will be processed at the end.
        if (nested_start > last_end_line + 1) {
            text_before = ""
            for (k = last_end_line + 1; k < nested_start; k++) {
                if (k <= n_content_lines) {
                    if (text_before != "") text_before = text_before "\n"
                    text_before = text_before content_lines[k]
                }
            }
            if (text_before != "") {
                # Process variables with functions (like split) before adding to result
                # This ensures that {{entry|split|pipe}} executes before {{entry|part|0}} is used
                text_before = process_variables_in_content(text_before)
                result = result text_before
            }
        }
        
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
            # Debug: trace if construct result if DAP_TPL_DEBUG is set
            if ("DAP_TPL_DEBUG" in ENVIRON && ENVIRON["DAP_TPL_DEBUG"] == "1") {
                if (content_text ~ /NORMALIZATION_MACROS_DATA|TYPE_TO_SELECT_DATA|BASIC_TYPES_DATA/) {
                    print "DEBUG: IF construct result length=" length(result_content) ", processed_content length=" length(processed_content) > "/dev/stderr"
                }
            }
            if (result_content != "") {
                result = result result_content
            }
        } else if (nested_type == "for") {
            # Use for_construct module to process for construct
            # Debug: trace for construct processing if DAP_TPL_DEBUG is set
            if ("DAP_TPL_DEBUG" in ENVIRON && ENVIRON["DAP_TPL_DEBUG"] == "1") {
                if (content_text ~ /NORMALIZATION_MACROS_DATA|TYPE_TO_SELECT_DATA|BASIC_TYPES_DATA/) {
                    print "DEBUG: Processing FOR construct: condition=" nested_condition ", content length=" length(nested_content) > "/dev/stderr"
                }
            }
            result_content = process_for_construct(nested_condition, nested_content, depth + 1)
            # Debug: trace for construct result if DAP_TPL_DEBUG is set
            if ("DAP_TPL_DEBUG" in ENVIRON && ENVIRON["DAP_TPL_DEBUG"] == "1") {
                if (content_text ~ /NORMALIZATION_MACROS_DATA|TYPE_TO_SELECT_DATA|BASIC_TYPES_DATA/) {
                    print "DEBUG: FOR construct result length=" length(result_content) > "/dev/stderr"
                }
            }
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
                # CRITICAL: Process variables in var_value after processing constructs
                # This ensures variables like {{entry|part|0}} are replaced before setting
                # But first, we need to process any variables with functions (like {{entry|split|pipe}})
                # that may be in the text before this construct, so that parts are available
                # for functions like {{entry|part|0}}
                var_value = process_variables_in_content(var_value)
                vars[var_name] = var_value
                ENVIRON[var_name] = var_value
            }
            # CRITICAL: set constructs don't produce output, they just set variables
            # So we don't add anything to result here
        } else {
            # Other types - process and add
            processed_nested = process_nested_constructs(nested_content, depth + 1)
            result = result processed_nested
        }
        
        # Update last_end_line to track position
        if (nested_end > last_end_line) {
            last_end_line = nested_end
        }
    }
    
    # Add text after last construct (if any)
    if (last_end_line < n_content_lines) {
        text_after = ""
        for (k = last_end_line + 1; k <= n_content_lines; k++) {
            if (text_after != "") text_after = text_after "\n"
            text_after = text_after content_lines[k]
        }
        if (text_after != "") {
            # Add text after constructs (variables will be processed later)
            result = result text_after
        }
    }
    
    # After processing constructs, process remaining variables (including function calls)
    # This processes variables in the entire result, including text between and after constructs
    # CRITICAL: This must happen AFTER all constructs are processed and variables are set
    # This ensures variables from {{#set}} inside constructs are available for replacement
    result = process_variables_in_content(result)
    
    # Debug: trace final result if DAP_TPL_DEBUG is set
    if ("DAP_TPL_DEBUG" in ENVIRON && ENVIRON["DAP_TPL_DEBUG"] == "1") {
        if (content_text ~ /NORMALIZATION_MACROS_DATA|TYPE_TO_SELECT_DATA|BASIC_TYPES_DATA/) {
            print "DEBUG: process_nested_constructs final result length=" length(result) ", depth=" depth > "/dev/stderr"
        }
    }
    
    return result
}

# Helper function to process variables in content (including function calls)
# CRITICAL: This function uses replace_variables from variable_replacer.awk
# to ensure consistent behavior and avoid code duplication
function process_variables_in_content(content_text,    processed_result) {
    # CRITICAL: Restore pipe characters that were escaped (\003 -> |) BEFORE processing
    # This prevents \003 from being misinterpreted as field separator during parsing
    processed_result = content_text
    gsub(/\003/, "|", processed_result)
    
    # Use replace_variables function from variable_replacer.awk for consistent behavior
    return replace_variables(processed_result)
}
