# Not Contains Operator Parser
# Parses: left not_contains 'text'

# Parse not_contains: left not_contains 'right'
# Parameters:
#   expr - expression string containing 'not_contains'
# Returns: parsed condition structure "not_contains|left|right"
function parse_not_contains(expr,    pos, left, right, result) {
    pos = match(expr, /[ \t]+not_contains[ \t]+/)
    left = substr(expr, 1, pos - 1)
    right = substr(expr, pos + RLENGTH)
    gsub(/^[ \t]+|[ \t]+$/, "", left)
    gsub(/^[ \t]+|[ \t]+$/, "", right)
    
    # Remove quotes
    if (match(right, /^['"'"'"](.*)['"'"'"]$/)) {
        right = substr(right, RSTART + 1, RLENGTH - 2)
    }
    
    result = "not_contains|" parse_simple_var(left) "|" right
    return result
}
