# Logical OR Condition Evaluator
# Evaluates: left || right

# Evaluate logical OR condition
# Parameters:
#   parts - array with parsed parts [1]=op, [2]=left, [3]=right (split by @@)
# Returns: 1 if left OR right is true, 0 otherwise
# NODISPATCH: internal helper with special calling convention
function evaluate_logical_or(parts) {
    return evaluate_parsed_condition(parts[2]) || evaluate_parsed_condition(parts[3])
}

