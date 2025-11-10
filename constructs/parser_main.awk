# Parse template constructs: if/else/for/set/awk
# Main parser that uses modular parsers
# Supports:
#   {{#if VAR}}...{{/if}}
#   {{#if VAR}}...{{else}}...{{/if}}
#   {{#for item in ARRAY}}...{{/for}}
#   {{#set VAR=value}}...{{/set}}
#   {{VAR}} - variable output
#   {{#awk:...}} - inline AWK script
#   Nested constructs are now supported via construct stack
# Output format: type|start_line|end_line|condition/var/script|content

# Include stack manager and marker detector
# Note: @include paths are relative to SCRIPTS_DIR environment variable
@include "constructs/stack_manager.awk"
@include "constructs/marker_detector.awk"
@include "constructs/parser_if.awk"
@include "constructs/parser_for.awk"
@include "constructs/parser_set.awk"
@include "constructs/parser_include.awk"
@include "constructs/parser_awk.awk"
@include "constructs/parser_closing.awk"

BEGIN {
    # Stack for nested constructs
    stack_size = 0
    line_num = 0
}

{
    line_num++
    line = $0
    
    # Try to process markers in order of specificity
    # Start with most specific markers first
    
    # Process include (self-contained, outputs immediately)
    if (line ~ /{{#include[ \t]/) {
        if (process_include_marker(line, line_num) == 2) {
            # Immediate output, check if remaining content needs processing
            if (match(line, /{{#include[ \t]+([^}]+)}}/)) {
                remaining = line
                sub(/{{#include[ \t]+[^}]+}}/, "", remaining)
                if (remaining != "") {
                    $0 = remaining
                    # Continue processing remaining content
                } else {
                    next
                }
            } else {
                next
            }
        }
    }
    
    # Process if construct
    if (line ~ /{{#if[ \t]/) {
        if (process_if_marker(line, line_num)) {
            next
        }
    }
    
    # Process for construct
    if (line ~ /{{#for[ \t]/) {
        if (process_for_marker(line, line_num)) {
            next
        }
    }
    
    # Process set construct
    if (line ~ /{{#set[ \t]/) {
        if (process_set_marker(line, line_num)) {
            next
        }
    }
    
    # Process awk construct
    if (line ~ /{{#awk:/) {
        result = process_awk_marker(line, line_num)
        if (result == 2) {
            # Immediate output
            next
        } else if (result == 1) {
            # Multi-line awk started
            next
        }
    }
    
    # Process else marker
    if (line ~ /{{else}}/) {
        if (process_else_marker(line, line_num)) {
            next
        }
    }
    
    # Process awk closing marker
    if (line ~ /^}}$/) {
        if (process_awk_closing(line_num)) {
            next
        }
    }
    
    # Process closing tags
    if (line ~ /{{(\/if|\/for|\/set|\/include)}}/) {
        if (process_closing_tag(line, line_num)) {
            next
        }
    }
    
    # Process var markers (no-op, but check for reference)
    if (line ~ /{{[^#\/][^}]*}}/ && stack_size == 0) {
        # Variables are processed directly in replace_template_constructs.awk
        # Do not create construct entries for simple variables
    }
    
    # Default action: accumulate content into current construct
    if (stack_size > 0) {
        # Don't process closing tags here - they're handled above
        if (match(line, /{{(\/if|\/for|\/set|\/include)}}/)) {
            # This is a closing tag - it should have been handled above
            # Skip this line to avoid double processing
            next
        }
        add_content(line)
        next
    }
}

END {
    # Output any remaining constructs on stack
    while (stack_size > 0) {
        type = stack[stack_size, "type"]
        condition = stack[stack_size, "condition"]
        start = stack[stack_size, "start_line"]
        content = stack[stack_size, "content"]
        in_else = stack[stack_size, "in_else"]
        else_start = stack[stack_size, "else_start_line"]
        else_content = stack[stack_size, "else_content"]
        
        # Replace newlines in content with special marker
        gsub(/\n/, "\001", content)
        if (type == "if" && in_else) {
            gsub(/\n/, "\001", else_content)
            # For if blocks with else, end should be line_num (end of file), not else_start
            print type "|" start "|" line_num "|" condition "|" content
            print "else|" else_start "|" line_num "||" else_content
        } else {
            print type "|" start "|" line_num "|" condition "|" content
        }
        
        pop_construct()
    }
}

