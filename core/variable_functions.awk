# Functions for processing variable functions: split, part, in_list, ne, contains
# Takes variable name, function name, function argument, and base value
# Returns processed value
# Note: This module uses ENVIRON and vars arrays directly for compatibility
# Variable context synchronization is handled by evaluators

# Process split function: splits value by delimiter and stores parts in ENVIRON and vars
function process_split(var_name, func_arg, base_value,    delimiter, n, parts_array, p, part_var) {
    delimiter = func_arg
    if (delimiter == "pipe" || delimiter == "|") {
        delimiter = "|"
    } else if (delimiter == "newline" || delimiter == "\\n") {
        delimiter = "\n"
    } else if (delimiter == " " || delimiter == "space") {
        delimiter = " "
    }
    n = split(base_value, parts_array, delimiter)
    # Store parts in both ENVIRON and vars for compatibility
    # Some code uses ENVIRON, some uses vars array
    # Evaluators will sync with variable_context as needed
    for (p = 1; p <= n; p++) {
        part_var = var_name "_parts_" (p-1)
        ENVIRON[part_var] = parts_array[p]
        vars[part_var] = parts_array[p]
    }
    ENVIRON[var_name "_parts_count"] = n
    vars[var_name "_parts_count"] = n
    # split function doesn't output anything - it just creates parts
    return ""
}

# Process part function: gets part by index
function process_part(var_name, func_arg, base_value,    index_str, index_num, part_var) {
    index_str = func_arg
    gsub(/^[ \t]+|[ \t]+$/, "", index_str)
    index_num = int(index_str)
    part_var = var_name "_parts_" index_num
    # Check vars first (for variables set by {{#set}}), then ENVIRON
    # Note: variable_context is checked by evaluators before calling this function
    if (part_var in vars) {
        return vars[part_var]
    } else if (part_var in ENVIRON) {
        return ENVIRON[part_var]
    }
    return ""
}

# Process contains function: checks if contains substring
function process_contains(base_value, func_arg,    substring) {
    substring = func_arg
    if (index(base_value, substring) > 0) {
        return "1"
    } else {
        return "0"
    }
}

# Process ne function: not equal
function process_ne(base_value, func_arg,    compare_value) {
    compare_value = func_arg
    if (base_value != compare_value) {
        return "1"
    } else {
        return "0"
    }
}

# Process in_list function: checks if value is in list
function process_in_list(base_value, func_arg,    list_var_name, list_value, found, n, items, i) {
    list_var_name = func_arg
    gsub(/^[ \t]+|[ \t]+$/, "", list_var_name)
    list_value = ""
    if (list_var_name in ENVIRON) {
        list_value = ENVIRON[list_var_name]
    }
    
    found = 0
    if (list_value != "" && base_value != "") {
        n = split(list_value, items, _NEWLINE "|\\|")
        for (i = 1; i <= n; i++) {
            gsub(/^[ \t]+|[ \t]+$/, "", items[i])
            if (items[i] == base_value) {
                found = 1
                break
            }
        }
    }
    return found ? "1" : "0"
}

# Process replace function: replaces all occurrences of pattern with replacement
function process_replace(base_value, func_arg,    pattern, replacement, result, parts) {
    # func_arg format: "pattern|replacement" or "pattern replacement"
    if (index(func_arg, "|") > 0) {
        n = split(func_arg, parts, "|")
        pattern = parts[1]
        replacement = (n > 1) ? parts[2] : ""
    } else {
        n = split(func_arg, parts, " ")
        pattern = parts[1]
        replacement = (n > 1) ? parts[2] : ""
    }
    result = base_value
    gsub(pattern, replacement, result)
    return result
}

# Process remove_suffix function: removes suffix from string
function process_remove_suffix(base_value, func_arg,    suffix, result) {
    suffix = func_arg
    gsub(/^[ \t]+|[ \t]+$/, "", suffix)
    result = base_value
    if (match(result, suffix "$")) {
        result = substr(result, 1, RSTART - 1)
    }
    return result
}

# Process trim function: removes leading and trailing whitespace
function process_trim(base_value, func_arg,    result) {
    result = base_value
    gsub(/^[ \t]+|[ \t]+$/, "", result)
    return result
}

# ---------------------------------------------------------------------------
# Native recursive-descent integer arithmetic evaluator.
# Eliminates subprocess spawning — all evaluation is in-process.
#
# Grammar (operator precedence, lowest→highest):
#   expr           → additive
#   additive       → multiplicative (('+' | '-') multiplicative)*
#   multiplicative → unary (('*' | '/' | '%') unary)*
#   unary          → '-' unary | primary
#   primary        → '(' expr ')' | integer
# ---------------------------------------------------------------------------
function _eval_peek(   ch) {
    if (_eval_pos > _eval_len) return ""
    return substr(_eval_str, _eval_pos, 1)
}
function _eval_skip_ws() {
    while (_eval_pos <= _eval_len && substr(_eval_str, _eval_pos, 1) ~ /[ \t]/)
        _eval_pos++
}
function _eval_primary(    ch, num, neg, val) {
    _eval_skip_ws()
    ch = _eval_peek()
    if (ch == "(") {
        _eval_pos++
        val = _eval_additive()
        _eval_skip_ws()
        if (_eval_peek() == ")") _eval_pos++
        return val
    }
    neg = 0
    if (ch == "-") { neg = 1; _eval_pos++ }
    _eval_skip_ws()
    num = 0
    while (_eval_pos <= _eval_len && substr(_eval_str, _eval_pos, 1) ~ /[0-9]/) {
        num = num * 10 + int(substr(_eval_str, _eval_pos, 1))
        _eval_pos++
    }
    return neg ? -num : num
}
function _eval_multiplicative(    val, op) {
    val = _eval_primary()
    while (1) {
        _eval_skip_ws()
        op = _eval_peek()
        if (op != "*" && op != "/" && op != "%") break
        _eval_pos++
        if (op == "*") val = val * _eval_primary()
        else if (op == "/") { val = int(val / _eval_primary()) }
        else { val = val % _eval_primary() }
    }
    return val
}
function _eval_additive(    val, op) {
    val = _eval_multiplicative()
    while (1) {
        _eval_skip_ws()
        op = _eval_peek()
        if (op != "+" && op != "-") break
        _eval_pos++
        if (op == "+") val = val + _eval_multiplicative()
        else val = val - _eval_multiplicative()
    }
    return val
}
function _eval_expr(expr) {
    _eval_str = expr
    _eval_len = length(expr)
    _eval_pos = 1
    return int(_eval_additive())
}

# ---------------------------------------------------------------------------
# Resolve variable names in an arithmetic expression string.
# Scans for [a-zA-Z_][a-zA-Z0-9_]* tokens, replaces with ENVIRON value.
# ---------------------------------------------------------------------------
function _resolve_vars_in_expr(expr,    result, i, ch, name) {
    result = ""
    i = 1
    while (i <= length(expr)) {
        ch = substr(expr, i, 1)
        if (ch ~ /[a-zA-Z_]/) {
            name = ""
            while (i <= length(expr) && substr(expr, i, 1) ~ /[a-zA-Z0-9_]/) {
                name = name substr(expr, i, 1)
                i++
            }
            if (name in ENVIRON && ENVIRON[name] ~ /^-?[0-9]+$/) {
                result = result ENVIRON[name]
            } else {
                result = result "0"
            }
        } else {
            result = result ch
            i++
        }
    }
    return result
}

# ---------------------------------------------------------------------------
# math: evaluate arithmetic on the base value — zero-subprocess
#   {{X|math|$+1}}      — X + 1
#   {{X|math|($+1)%5}}  — (X + 1) mod 5
#   $ is replaced with the base value; variable names are resolved from ENVIRON.
# ---------------------------------------------------------------------------
function process_math(base_value, func_arg,    expr, resolved) {
    expr = func_arg
    gsub(/\$/, int(base_value) "", expr)
    resolved = _resolve_vars_in_expr(expr)
    return _eval_expr(resolved)
}

# ---------------------------------------------------------------------------
# at: indexed access into a pipe-separated list (0-based) — zero-subprocess
#   {{LIST|at|3}}        — element 3 (literal)
#   {{LIST|at|x}}        — element at ENVIRON["x"]
#   {{LIST|at|x+5}}      — element at computed index
# ---------------------------------------------------------------------------
function process_at(base_value, func_arg,    idx_str, idx, n, items) {
    idx_str = func_arg
    gsub(/^[ \t]+|[ \t]+$/, "", idx_str)
    if (idx_str ~ /^[0-9]+$/) {
        idx = int(idx_str)
    } else if (idx_str in ENVIRON && ENVIRON[idx_str] ~ /^-?[0-9]+$/) {
        idx = int(ENVIRON[idx_str])
    } else {
        idx = _eval_expr(_resolve_vars_in_expr(idx_str))
    }
    n = split(base_value, items, /\|/)
    idx = idx + 1
    if (idx >= 1 && idx <= n) {
        gsub(/^[ \t]+|[ \t]+$/, "", items[idx])
        return items[idx]
    }
    return ""
}

# ---------------------------------------------------------------------------
# resolve: indirect variable reference
#   {{rnd|resolve|MAP_}}  — returns value of ENVIRON["MAP_" .. base_value]
#   {{X|resolve}}          — returns value of ENVIRON[base_value]
# ---------------------------------------------------------------------------
function process_resolve(base_value, func_arg,    var_name) {
    if (func_arg != "") {
        var_name = func_arg base_value
    } else {
        var_name = base_value
    }
    if (var_name in ENVIRON) {
        return ENVIRON[var_name]
    }
    return ""
}

# Variable function dispatch table
# Maps function names to handler function names
# Functions are categorized by their signature:
#   - VAR_FUNC_NEEDS_VARNAME: functions that need var_name parameter (split, part)
#   - VAR_FUNC_DISPATCH: all other functions (base_value, func_arg)
BEGIN {
    # Register core variable functions that need var_name
    VAR_FUNC_NEEDS_VARNAME["split"] = 1
    VAR_FUNC_NEEDS_VARNAME["part"] = 1
    
    # Register core variable functions
    VAR_FUNC_DISPATCH["split"] = "process_split"
    VAR_FUNC_DISPATCH["part"] = "process_part"
    VAR_FUNC_DISPATCH["contains"] = "process_contains"
    VAR_FUNC_DISPATCH["ne"] = "process_ne"
    VAR_FUNC_DISPATCH["in_list"] = "process_in_list"
    VAR_FUNC_DISPATCH["replace"] = "process_replace"
    VAR_FUNC_DISPATCH["remove_suffix"] = "process_remove_suffix"
    VAR_FUNC_DISPATCH["trim"] = "process_trim"
    VAR_FUNC_DISPATCH["math"] = "process_math"
    VAR_FUNC_DISPATCH["at"] = "process_at"
    VAR_FUNC_DISPATCH["resolve"] = "process_resolve"
    # C-specific functions (normalize_name, escape_name, etc.) are registered by mocking extensions
}

# Register a variable function handler
# Parameters:
#   func_name - function name (e.g., "split", "trim")
#   handler_func - handler function name (e.g., "process_split")
#   needs_varname - 1 if function needs var_name parameter, 0 otherwise
function register_variable_function(func_name, handler_func, needs_varname) {
    VAR_FUNC_DISPATCH[func_name] = handler_func
    if (needs_varname) {
        VAR_FUNC_NEEDS_VARNAME[func_name] = 1
    }
}

# Apply a chain of variable functions: {{VAR|func1|arg1|func2|arg2|...}}
# Processes function pairs sequentially, passing each result to the next function.
# Returns the final result after all functions are applied.
function apply_function_chain(var_name, full_expr, base_value,    _fc_parts, _fc_n, _fc_i, _fc_func, _fc_arg, _fc_result) {
    _fc_n = split(full_expr, _fc_parts, "|")
    if (_fc_n < 2) return base_value

    _fc_result = base_value
    _fc_i = 2
    while (_fc_i <= _fc_n) {
        _fc_func = _fc_parts[_fc_i]
        _fc_arg = (_fc_i + 1 <= _fc_n) ? _fc_parts[_fc_i + 1] : ""
        _fc_i += 2
        _fc_result = process_variable_function(var_name, _fc_func, _fc_arg, _fc_result)
    }
    return _fc_result
}

# Main function to process variable function
# Uses dispatch table for extensible function handling
function process_variable_function(var_name, func_name, func_arg, base_value,    handler_func) {
    # Check dispatch table
    if (func_name in VAR_FUNC_DISPATCH) {
        handler_func = VAR_FUNC_DISPATCH[func_name]
        # Use indirect function call (GNU AWK feature)
        # Check if function needs var_name parameter
        if (func_name in VAR_FUNC_NEEDS_VARNAME) {
            return @handler_func(var_name, func_arg, base_value)
        }
        # For functions that only need base_value and func_arg
        return @handler_func(base_value, func_arg)
    }
    
    # Unknown function - return base value
    # Extensions can register additional functions via register_variable_function()
    return base_value
}

