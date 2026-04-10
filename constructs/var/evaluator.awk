# VAR Construct Evaluator
# Evaluates variable tokens: {{VAR}} and {{VAR|function|args}}

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/variable_functions.awk"
@include "core/marker_parser.awk"

# Evaluate variable token
# Parameters:
#   token_id - variable token ID
# Returns: text token ID with evaluated value, or 0 on error
function evaluate_var(token_id,    var_expr, parsed_expr, var_name, func_name, func_arg, base_value, result_value, text_token_id, parts_count_var, parts_count, part_var, p, _ev_parts, _ev_n) {
    var_expr = get_token_metadata(token_id, "var_name")
    if (var_expr == "") {
        return 0
    }
    
    # Parse variable expression
    parsed_expr = parse_var_expr(var_expr)
    var_name = get_var_name(parsed_expr)
    func_name = get_func_name(parsed_expr)
    func_arg = get_func_arg(parsed_expr)
    
    # Get base value from context (searches context stack and ENVIRON)
    base_value = get_var(var_name)
    
    # Ensure variable is in ENVIRON/vars for variable_functions.awk compatibility
    if (base_value != "" && !(var_name in ENVIRON)) {
        ENVIRON[var_name] = base_value
    }
    
    # Detect function chain: var|func1|arg1|func2|arg2|...
    _ev_n = split(var_expr, _ev_parts, "|")
    if (_ev_n > 3) {
        result_value = apply_function_chain(var_name, var_expr, base_value)
        # Sync split parts to variable_context (chain may contain split)
        parts_count_var = var_name "_parts_count"
        if (parts_count_var in ENVIRON) {
            parts_count = ENVIRON[parts_count_var]
            for (p = 0; p < parts_count; p++) {
                part_var = var_name "_parts_" p
                if (part_var in ENVIRON) set_var(part_var, ENVIRON[part_var])
            }
            set_var(parts_count_var, parts_count)
        }
    } else if (func_name == "part") {
        parts_count_var = var_name "_parts_count"
        parts_count = get_var(parts_count_var)
        if (parts_count != "") {
            part_var = var_name "_parts_" func_arg
            result_value = get_var(part_var)
        } else {
            result_value = process_variable_function(var_name, func_name, func_arg, base_value)
        }
    } else if (func_name != "") {
        result_value = process_variable_function(var_name, func_name, func_arg, base_value)
        if (func_name == "split") {
            parts_count_var = var_name "_parts_count"
            if (parts_count_var in ENVIRON) {
                parts_count = ENVIRON[parts_count_var]
                for (p = 0; p < parts_count; p++) {
                    part_var = var_name "_parts_" p
                    if (part_var in ENVIRON) set_var(part_var, ENVIRON[part_var])
                }
                set_var(parts_count_var, parts_count)
            }
        }
    } else {
        result_value = base_value
    }
    
    # Create text token with evaluated value
    text_token_id = create_token("text", result_value, "")
    
    return text_token_id
}

