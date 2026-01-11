# Logical AND Condition Parser
# Parses: left && right

# Parse logical AND: left && right
# Parameters:
#   expr - expression string containing &&
# Returns: parsed condition structure "AND@@left@@right" (using @@ as delimiter to avoid conflicts with | in sub-conditions)
function parse_logical_and(expr,    pos, left, right, result) {
    pos = match(expr, /[ \t]+&&[ \t]+/)
    left = substr(expr, 1, pos - 1)
    right = substr(expr, pos + RLENGTH)
    gsub(/^[ \t]+|[ \t]+$/, "", left)
    gsub(/^[ \t]+|[ \t]+$/, "", right)
    
    result = "AND@@" parse_condition(left) "@@" parse_condition(right)
    return result
}

