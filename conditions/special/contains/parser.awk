# Contains Operator Parser
# Parses: left contains 'text'

# Parse contains: left contains 'right'
# Parameters:
#   expr - expression string containing 'contains'
# Returns: parsed condition structure "contains|left|right"
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

