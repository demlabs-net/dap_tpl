# Condition Parser
# Parses improved condition syntax with operators and logical expressions
# Supports: VAR, VAR != 0, VAR > 5, VAR contains 'text', VAR in LIST, VAR matches 'pattern'
# Also supports: VAR && VAR2, VAR || VAR2, !VAR

# Parse condition expression with operators
# Parameters:
#   condition_expr - condition expression
# Returns: parsed condition structure (for evaluation)
function parse_condition(condition_expr,    trimmed, result) {
    trimmed = condition_expr
    gsub(/^[ \t]+|[ \t]+$/, "", trimmed)
    
    if (trimmed == "") {
        return ""
    }
    
    # Check for logical operators (lowest priority)
    if (match(trimmed, /[ \t]+&&[ \t]+/)) {
        return parse_logical_and(trimmed)
    }
    if (match(trimmed, /[ \t]+\|\|[ \t]+/)) {
        return parse_logical_or(trimmed)
    }
    if (match(trimmed, /^![ \t]+/)) {
        return parse_logical_not(trimmed)
    }
    
    # Check for comparison operators
    # Note: Order matters - >= and <= must be checked before > and <
    if (match(trimmed, /[ \t]+!=[ \t]+/)) {
        return parse_comparison(trimmed, "!=", RSTART, RLENGTH)
    }
    if (match(trimmed, /[ \t]+==[ \t]+/)) {
        return parse_comparison(trimmed, "==", RSTART, RLENGTH)
    }
    if (match(trimmed, /[ \t]+>=[ \t]+/)) {
        return parse_comparison(trimmed, ">=", RSTART, RLENGTH)
    }
    if (match(trimmed, /[ \t]+<=[ \t]+/)) {
        return parse_comparison(trimmed, "<=", RSTART, RLENGTH)
    }
    if (match(trimmed, /[ \t]+>[ \t]+/)) {
        return parse_comparison(trimmed, ">", RSTART, RLENGTH)
    }
    if (match(trimmed, /[ \t]+<[ \t]+/)) {
        return parse_comparison(trimmed, "<", RSTART, RLENGTH)
    }
    
    # Check for special operators
    if (match(trimmed, /[ \t]+contains[ \t]+/)) {
        return parse_contains(trimmed)
    }
    if (match(trimmed, /[ \t]+in[ \t]+/)) {
        return parse_in_list(trimmed)
    }
    if (match(trimmed, /[ \t]+matches[ \t]+/)) {
        return parse_matches(trimmed)
    }
    
    # Simple variable check
    return parse_simple_var(trimmed)
}

# Parse logical AND: left && right
function parse_logical_and(expr,    pos, left, right, result) {
    pos = match(expr, /[ \t]+&&[ \t]+/)
    left = substr(expr, 1, pos - 1)
    right = substr(expr, pos + RLENGTH)
    gsub(/^[ \t]+|[ \t]+$/, "", left)
    gsub(/^[ \t]+|[ \t]+$/, "", right)
    
    result = "AND|" parse_condition(left) "|" parse_condition(right)
    return result
}

# Parse logical OR: left || right
function parse_logical_or(expr,    pos, left, right, result) {
    pos = match(expr, /[ \t]+\|\|[ \t]+/)
    left = substr(expr, 1, pos - 1)
    right = substr(expr, pos + RLENGTH)
    gsub(/^[ \t]+|[ \t]+$/, "", left)
    gsub(/^[ \t]+|[ \t]+$/, "", right)
    
    result = "OR|" parse_condition(left) "|" parse_condition(right)
    return result
}

# Parse logical NOT: !expr
function parse_logical_not(expr,    rest, result) {
    rest = substr(expr, 2)
    gsub(/^[ \t]+|[ \t]+$/, "", rest)
    
    result = "NOT|" parse_condition(rest)
    return result
}

# Parse comparison: left OP right
function parse_comparison(expr, op, match_pos, match_len,    pos, left, right, result) {
    # Use match position if provided, otherwise use index()
    if (match_pos > 0) {
        pos = match_pos
        # Extract operator with surrounding whitespace
        left = substr(expr, 1, pos - 1)
        right = substr(expr, pos + match_len)
    } else {
        pos = index(expr, op)
        left = substr(expr, 1, pos - 1)
        right = substr(expr, pos + length(op))
    }
    gsub(/^[ \t]+|[ \t]+$/, "", left)
    gsub(/^[ \t]+|[ \t]+$/, "", right)
    
    # Remove quotes from right if present
    if (match(right, /^['"'"'"](.*)['"'"'"]$/)) {
        right = substr(right, RSTART + 1, RLENGTH - 2)
    }
    
    # Parse left side - can be variable or variable with function
    parsed_left = parse_simple_var(left)
    result = op "|" parsed_left "|" right
    return result
}

# Parse contains: left contains 'right'
function parse_contains(expr,    pos, left, right, result) {
    pos = match(expr, /[ \t]+contains[ \t]+/)
    left = substr(expr, 1, pos - 1)
    right = substr(expr, pos + RLENGTH)
    gsub(/^[ \t]+|[ \t]+$/, "", left)
    gsub(/^[ \t]+|[ \t]+$/, "", right)
    
    # Remove quotes
    if (match(right, /^['"'"'"](.*)['"'"'"]$/)) {
        right = substr(right, RSTART + 1, RLENGTH - 2)
    }
    
    result = "contains|" parse_simple_var(left) "|" right
    return result
}

# Parse in list: left in right
function parse_in_list(expr,    pos, left, right, result) {
    pos = match(expr, /[ \t]+in[ \t]+/)
    left = substr(expr, 1, pos - 1)
    right = substr(expr, pos + RLENGTH)
    gsub(/^[ \t]+|[ \t]+$/, "", left)
    gsub(/^[ \t]+|[ \t]+$/, "", right)
    
    result = "in|" parse_simple_var(left) "|" parse_simple_var(right)
    return result
}

# Parse matches: left matches 'pattern'
function parse_matches(expr,    pos, left, right, result) {
    pos = match(expr, /[ \t]+matches[ \t]+/)
    left = substr(expr, 1, pos - 1)
    right = substr(expr, pos + RLENGTH)
    gsub(/^[ \t]+|[ \t]+$/, "", left)
    gsub(/^[ \t]+|[ \t]+$/, "", right)
    
    # Remove quotes
    if (match(right, /^['"'"'"](.*)['"'"'"]$/)) {
        right = substr(right, RSTART + 1, RLENGTH - 2)
    }
    
    result = "matches|" parse_simple_var(left) "|" right
    return result
}

# Parse simple variable (may have function calls)
function parse_simple_var(expr,    parsed_expr) {
    # Use existing marker_parser for variable expressions
    parsed_expr = parse_var_expr(expr)
    return parsed_expr
}

# Evaluate parsed condition
# Parameters:
#   parsed_cond - parsed condition from parse_condition()
# Returns: 1 if true, 0 if false
function evaluate_parsed_condition(parsed_cond,    parts, op, left, right, left_val, right_val, var_name, func_name, func_arg, base_value) {
    if (parsed_cond == "") {
        return 0
    }
    
    split(parsed_cond, parts, "|")
    op = parts[1]
    
    if (op == "AND") {
        return evaluate_parsed_condition(parts[2]) && evaluate_parsed_condition(parts[3])
    }
    if (op == "OR") {
        return evaluate_parsed_condition(parts[2]) || evaluate_parsed_condition(parts[3])
    }
    if (op == "NOT") {
        return !evaluate_parsed_condition(parts[2])
    }
    
    # Check if this is a simple variable (no operator, format: VAR||)
    # In this case, parts[1] is the variable name, parts[2] and parts[3] are empty
    if (parts[2] == "" && parts[3] == "" && op != "!=" && op != "==" && op != ">" && op != ">=" && op != "<" && op != "<=" && op != "contains" && op != "in" && op != "matches") {
        # Simple variable check - use op as variable name
        var_name = op
        func_name = ""
        func_arg = ""
        base_value = get_var(var_name)
        left_val = base_value
    } else {
        # Get left value - reconstruct from parts[2] onwards until we find the right value
        # Format is: op|left|right, but left may contain | (e.g., VAR||)
        # So we need to find where left ends and right begins
        # Left part is everything from parts[2] to the last empty part before right
        left = parts[2]
        # If parts[3] is empty and parts[4] exists, then left is parts[2]|| and right is parts[4]
        # Otherwise, left is parts[2] and right is parts[3]
        if (parts[3] == "" && length(parts) > 3 && parts[4] != "") {
            # Left is VAR|| format, right is in parts[4]
            right_start = 4
        } else if (parts[3] == "" && length(parts) > 4 && parts[5] != "") {
            # Left is VAR|| format, right is in parts[5]
            right_start = 5
        } else {
            # Standard format: left is parts[2], right is parts[3]
            right_start = 3
        }
        
        var_name = get_var_name(left)
        func_name = get_func_name(left)
        func_arg = get_func_arg(left)
        base_value = get_var(var_name)
        
        if (func_name != "") {
            left_val = process_variable_function(var_name, func_name, func_arg, base_value)
        } else {
            left_val = base_value
        }
    }
    
    # Comparison operators
    if (op == "!=" || op == "==" || op == ">" || op == ">=" || op == "<" || op == "<=") {
        # Get right value - find the last non-empty part
        right = ""
        for (i = length(parts); i >= 3; i--) {
            if (parts[i] != "") {
                right = parts[i]
                break
            }
        }
        # Remove quotes if present
        if (match(right, /^['"'"'"](.*)['"'"'"]$/)) {
            right = substr(right, RSTART + 1, RLENGTH - 2)
        }
        
        if (op == "!=") {
            return (left_val != right) ? 1 : 0
        }
        if (op == "==") {
            return (left_val == right) ? 1 : 0
        }
        if (op == ">") {
            return (left_val + 0 > right + 0) ? 1 : 0
        }
        if (op == ">=") {
            return (left_val + 0 >= right + 0) ? 1 : 0
        }
        if (op == "<") {
            return (left_val + 0 < right + 0) ? 1 : 0
        }
        if (op == "<=") {
            return (left_val + 0 <= right + 0) ? 1 : 0
        }
    }
    if (op == "contains") {
        # Get right value - find the last non-empty part
        right = ""
        for (i = length(parts); i >= 3; i--) {
            if (parts[i] != "") {
                right = parts[i]
                break
            }
        }
        # Remove quotes if present
        if (match(right, /^['"'"'"](.*)['"'"'"]$/)) {
            right = substr(right, RSTART + 1, RLENGTH - 2)
        }
        return (index(left_val, right) > 0) ? 1 : 0
    }
    if (op == "in") {
        # Get right value - find the last non-empty part
        right = ""
        for (i = length(parts); i >= 3; i--) {
            if (parts[i] != "") {
                right = parts[i]
                break
            }
        }
        var_name = get_var_name(right)
        base_value = get_var(var_name)
        return process_in_list(left_val, base_value) == "1" ? 1 : 0
    }
    if (op == "matches") {
        # Get right value - find the last non-empty part
        right = ""
        for (i = length(parts); i >= 3; i--) {
            if (parts[i] != "") {
                right = parts[i]
                break
            }
        }
        # Remove quotes if present
        if (match(right, /^['"'"'"](.*)['"'"'"]$/)) {
            right = substr(right, RSTART + 1, RLENGTH - 2)
        }
        return (match(left_val, right) > 0) ? 1 : 0
    }
    
    # Default: boolean check (non-empty and not "0")
    if (left_val != "" && left_val != "0") {
        return 1
    }
    return 0
}

