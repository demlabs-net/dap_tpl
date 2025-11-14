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
function process_part(var_name, func_arg,    index_str, index_num, part_var) {
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
        n = split(list_value, items, /\n|\|/)
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

