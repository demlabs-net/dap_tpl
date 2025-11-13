# Matches Operator Parser
# Parses: left matches 'pattern'

# Parse matches: left matches 'pattern'
# Parameters:
#   expr - expression string containing 'matches'
# Returns: parsed condition structure "matches|left|pattern"
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

