# SH Section Extensions Registry (Core)
# Provides extension mechanism for SH sections
# Extensions can register environment variables, output filters, and callbacks
# This keeps dap_tpl core clean from project-specific logic

# Registry for environment variables to include in SH sections
# Format: sh_env_vars[var_name] = 1
# Arrays are initialized automatically in AWK

# Registry for output line filters (regex patterns)
# Format: sh_output_filters[pattern] = 1
# Arrays are initialized automatically in AWK

# Registry for callback functions
# Format: sh_callbacks[callback_name] = callback_function_name
# Arrays are initialized automatically in AWK

# Register environment variable to include in SH sections
# Parameters:
#   var_name - environment variable name
function register_sh_env_var(var_name) {
    sh_env_vars[var_name] = 1
}

# Register output filter pattern for SH sections
# Parameters:
#   pattern - regex pattern to filter out from output
function register_sh_output_filter(pattern) {
    sh_output_filters[pattern] = 1
}

# Register callback function for SH section processing
# Parameters:
#   callback_name - name of callback (e.g., "before_execute", "after_execute")
#   callback_func - function name to call
function register_sh_callback(callback_name, callback_func) {
    sh_callbacks[callback_name] = callback_func
}

# Call registered callback function
# Parameters:
#   callback_name - name of callback to call
# Returns: callback return value or empty string if callback not registered
function call_sh_callback(callback_name,    callback_func) {
    if (callback_name in sh_callbacks) {
        callback_func = sh_callbacks[callback_name]
        # Use indirect function call
        return @callback_func()
    }
    return ""
}

# Call registered callback with arguments (up to 3 args)
# Parameters:
#   callback_name - name of callback to call
#   arg1, arg2, arg3 - arguments to pass
# Returns: callback return value or empty string if callback not registered
function call_sh_callback_with_args(callback_name, arg1, arg2, arg3,    callback_func) {
    if (callback_name in sh_callbacks) {
        callback_func = sh_callbacks[callback_name]
        # Use indirect function call with arguments
        return @callback_func(arg1, arg2, arg3)
    }
    return ""
}

# Check if line should be filtered from SH output
# Parameters:
#   line - output line to check
# Returns: 1 if line should be filtered, 0 otherwise
function should_filter_sh_output_line(line,    pattern) {
    # Check against all registered filters
    for (pattern in sh_output_filters) {
        if (line ~ pattern) {
            return 1
        }
    }
    return 0
}
