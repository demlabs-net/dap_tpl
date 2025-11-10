# Parser for variable markers: {{VAR}} and {{VAR|function|args}}
# Extracts variable name, function name, and function arguments from markers

# Parse marker and extract variable expression
function parse_marker(marker_text,    var_expr) {
    # CRITICAL: Restore pipe characters (\003 -> |) BEFORE parsing
    # This ensures correct marker matching and substring extraction
    # \003 is used as temporary escape for | in content, but must be restored before parsing
    marker_restored = marker_text
    gsub(/\003/, "|", marker_restored)
    
    # Extract var_expr from {{VAR}} or {{VAR|function|args}}
    if (match(marker_restored, /{{[^#\/][^}]*}}/)) {
        var_expr = substr(marker_restored, RSTART + 2, RLENGTH - 4)
        gsub(/^[ \t]+|[ \t]+$/, "", var_expr)
        return var_expr
    }
    return ""
}

# Parse variable expression into parts: var_name, func_name, func_arg
function parse_var_expr(var_expr,    func_parts, var_name, func_name, func_arg) {
    if (match(var_expr, /^([^|]+)\|([^|]+)(\|(.+))?$/)) {
        split(var_expr, func_parts, "|")
        var_name = func_parts[1]
        func_name = func_parts[2]
        func_arg = ""
        if (length(func_parts) > 2) {
            func_arg = func_parts[3]
        }
        return var_name "|" func_name "|" func_arg
    } else {
        # Simple variable, no function
        return var_expr "||"
    }
}

# Extract parts from parsed expression
function get_var_name(parsed_expr,    parts) {
    split(parsed_expr, parts, "|")
    return parts[1]
}

function get_func_name(parsed_expr,    parts) {
    split(parsed_expr, parts, "|")
    return parts[2]
}

function get_func_arg(parsed_expr,    parts) {
    split(parsed_expr, parts, "|")
    return parts[3]
}

