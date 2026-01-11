# Logical NOT Condition Parser
# Parses: !expr

# Parse logical NOT: !expr
# Parameters:
#   expr - expression string starting with !
# Returns: parsed condition structure "NOT@@expr" (using @@ as delimiter to avoid conflicts with | in sub-conditions)
function parse_logical_not(expr,    rest, result) {
    rest = substr(expr, 2)
    gsub(/^[ \t]+|[ \t]+$/, "", rest)
    
    result = "NOT@@" parse_condition(rest)
    return result
}

