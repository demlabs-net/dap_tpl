# Logical NOT Condition Evaluator
# Evaluates: !expr

# Evaluate logical NOT condition
# Parameters:
#   parts - array with parsed parts [1]=op, [2]=expr
# Returns: 1 if expr is false, 0 if expr is true
function evaluate_logical_not(parts) {
    return !evaluate_parsed_condition(parts[2])
}

