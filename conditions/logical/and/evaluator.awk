# Logical AND Condition Evaluator
# Evaluates: left && right

# Evaluate logical AND condition
# Parameters:
#   parts - array with parsed parts [1]=op, [2]=left, [3]=right
# Returns: 1 if both left AND right are true, 0 otherwise
function evaluate_logical_and(parts) {
    return evaluate_parsed_condition(parts[2]) && evaluate_parsed_condition(parts[3])
}

