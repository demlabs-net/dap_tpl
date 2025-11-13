# Logical OR Condition Parser
# Parses: left || right

# Parse logical OR: left || right
# Parameters:
#   expr - expression string containing ||
# Returns: parsed condition structure "OR|left|right"
function parse_logical_or(expr,    pos, left, right, result) {
    pos = match(expr, /[ \t]+\|\|[ \t]+/)
    left = substr(expr, 1, pos - 1)
    right = substr(expr, pos + RLENGTH)
    gsub(/^[ \t]+|[ \t]+$/, "", left)
    gsub(/^[ \t]+|[ \t]+$/, "", right)
    
    result = "OR|" parse_condition(left) "|" parse_condition(right)
    return result
}

