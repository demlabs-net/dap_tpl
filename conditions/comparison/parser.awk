# Comparison Operators Parser
# Parses: left OP right where OP is: ==, !=, >, <, >=, <=

# Parse comparison: left OP right
# Parameters:
#   expr - expression string
#   op - comparison operator (==, !=, >, <, >=, <=)
#   match_pos - position where operator was found
#   match_len - length of operator match
# Returns: parsed condition structure "OP|left|right"
function parse_comparison(expr, op, match_pos, match_len,    pos, left, right, result, parsed_left) {
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

