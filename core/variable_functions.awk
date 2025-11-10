# Functions for processing variable functions: split, part, in_list, ne, contains
# Takes variable name, function name, function argument, and base value
# Returns processed value

# Process split function: splits value by delimiter and stores parts in ENVIRON
function process_split(var_name, func_arg, base_value,    delimiter, n, parts_array, p) {
    delimiter = func_arg
    if (delimiter == "pipe" || delimiter == "|") {
        delimiter = "|"
    } else if (delimiter == "newline" || delimiter == "\\n") {
        delimiter = "\n"
    }
    n = split(base_value, parts_array, delimiter)
    # Store parts in ENVIRON for later access
    for (p = 1; p <= n; p++) {
        ENVIRON[var_name "_parts_" (p-1)] = parts_array[p]
    }
    ENVIRON[var_name "_parts_count"] = n
    # split function doesn't output anything - it just creates parts
    return ""
}

# Process part function: gets part by index
function process_part(var_name, func_arg,    index_str, index_num, part_var) {
    index_str = func_arg
    gsub(/^[ \t]+|[ \t]+$/, "", index_str)
    index_num = int(index_str)
    part_var = var_name "_parts_" index_num
    if (part_var in ENVIRON) {
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

# Main function to process variable function
function process_variable_function(var_name, func_name, func_arg, base_value,    result) {
    if (func_name == "split") {
        return process_split(var_name, func_arg, base_value)
    } else if (func_name == "part") {
        return process_part(var_name, func_arg)
    } else if (func_name == "contains") {
        return process_contains(base_value, func_arg)
    } else if (func_name == "ne") {
        return process_ne(base_value, func_arg)
    } else if (func_name == "in_list") {
        return process_in_list(base_value, func_arg)
    } else {
        # Unknown function - return base value
        return base_value
    }
}

