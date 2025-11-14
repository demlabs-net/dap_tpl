# Debug Output Manager
# Centralized debug output control for dap_tpl engine
# Usage: Set DEBUG_ENABLED environment variable to enable debug output
#        Set DEBUG_CATEGORIES to filter specific debug categories
#
# Each file should set DEBUG_FILE_NAME at the top:
#   BEGIN { DEBUG_FILE_NAME = "conditional_evaluator_helpers" }
# Then use debug_print_auto() which automatically uses DEBUG_FILE_NAME as category

# Debug categories
# Categories can be enabled individually via DEBUG_CATEGORIES environment variable
# Format: DEBUG_CATEGORIES="comparison,if,tokenizer" (comma-separated)
# If DEBUG_CATEGORIES is not set, all categories are enabled when DEBUG_ENABLED=1

BEGIN {
    # Check if debug is enabled
    DEBUG_ENABLED = (ENVIRON["DEBUG_ENABLED"] == "1" || ENVIRON["DEBUG_ENABLED"] == "true")
    
    # Parse debug categories if specified
    DEBUG_CATEGORIES_STR = ENVIRON["DEBUG_CATEGORIES"]
    if (DEBUG_CATEGORIES_STR != "") {
        split(DEBUG_CATEGORIES_STR, DEBUG_CATEGORIES_ARR, /[, \t]+/)
        for (i in DEBUG_CATEGORIES_ARR) {
            DEBUG_CATEGORIES[DEBUG_CATEGORIES_ARR[i]] = 1
        }
    }
}

# Extract category from file path
# Parameters:
#   file_path - full file path
# Returns: category name (filename without extension)
function extract_category_from_path(file_path,    basename, category) {
    # Extract basename (last component of path)
    if (match(file_path, /\/([^\/]+)$/)) {
        basename = substr(file_path, RSTART + 1, RLENGTH - 1)
    } else {
        basename = file_path
    }
    
    # Remove extension
    if (match(basename, /^(.+)\.[^.]+$/)) {
        category = substr(basename, RSTART, RLENGTH - length(substr(basename, RSTART + RLENGTH)))
    } else {
        category = basename
    }
    
    return category
}

# Check if debug category is enabled
# Parameters:
#   category - debug category name
# Returns: 1 if enabled, 0 otherwise
function is_debug_enabled(category) {
    if (!DEBUG_ENABLED) {
        return 0
    }
    
    # If no categories specified, all are enabled
    if (length(DEBUG_CATEGORIES) == 0) {
        return 1
    }
    
    # Check if category is in enabled list
    return (category in DEBUG_CATEGORIES) ? 1 : 0
}

# Print debug message
# Parameters:
#   category - debug category (e.g., "comparison", "if", "tokenizer")
#   message - debug message to print
function debug_print(category, message) {
    if (is_debug_enabled(category)) {
        printf "DEBUG[%s]: %s\n", category, message > "/dev/stderr"
    }
}

# Print debug message with format string
# Parameters:
#   category - debug category
#   format - printf format string
#   ... - variable number of arguments (up to 10)
# Note: AWK doesn't support variadic functions, so we use a workaround
# For more arguments, use debug_print with sprintf
function debug_printf(category, format,    result) {
    if (is_debug_enabled(category)) {
        # Use sprintf to format the message, then print with category prefix
        # This is a workaround for AWK's lack of variadic functions
        # For now, we'll use a simpler approach - just print format as-is
        # Callers should use sprintf themselves if they need formatting
        printf "DEBUG[%s]: %s\n", category, format > "/dev/stderr"
    }
}

# Log debug message - automatically uses DEBUG_FILE_NAME as category
# Parameters:
#   format - sprintf format string (can contain %s, %d, etc.)
#   arg1, arg2, ... - optional arguments for sprintf (up to 5 arguments supported)
# Note: Each file should set DEBUG_FILE_NAME at the top (in BEGIN block or before first use)
# Usage examples:
#   log_debug("simple message")
#   log_debug("value: %s", value)
#   log_debug("id=%d name=%s", id, name)
# Note: AWK doesn't support variadic functions, so we detect arguments by checking
# if format contains format specifiers (%s, %d, etc.) and count them
function log_debug(format, arg1, arg2, arg3, arg4, arg5,    category, message, format_spec_count, format_copy) {
    category = (DEBUG_FILE_NAME == "") ? "unknown" : DEBUG_FILE_NAME
    
    # Count format specifiers in format string
    format_spec_count = 0
    format_copy = format
    # Simple heuristic: count % followed by a letter (s, d, f, etc.)
    # This is not perfect but works for most cases
    while (match(format_copy, /%[sdioxXucfgeEG]/)) {
        format_spec_count++
        format_copy = substr(format_copy, RSTART + RLENGTH)
    }
    
    # If format specifiers found, use sprintf with arguments
    if (format_spec_count > 0) {
        if (format_spec_count == 1) {
            message = sprintf(format, arg1)
        } else if (format_spec_count == 2) {
            message = sprintf(format, arg1, arg2)
        } else if (format_spec_count == 3) {
            message = sprintf(format, arg1, arg2, arg3)
        } else if (format_spec_count == 4) {
            message = sprintf(format, arg1, arg2, arg3, arg4)
        } else if (format_spec_count == 5) {
            message = sprintf(format, arg1, arg2, arg3, arg4, arg5)
        } else {
            # Too many specifiers - just use format as-is
            message = format
        }
    } else {
        # No format specifiers - use format as-is
        message = format
    }
    
    debug_print(category, message)
}

