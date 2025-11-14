# Variable Context Management
# Provides stack-based variable scoping for template processing
# Uses GAWK 4+ true multidimensional arrays: contexts[level]["vars"][name]
# Note: This is the new Clean Architecture implementation

# Context structure:
#   contexts[level]["vars"][var_name] - variable value
#   contexts[level]["parent"] - parent context level (for nested scopes)

BEGIN {
    # Global context stack
    context_level = 0
}

# Push a new context level (enters a new scope)
# Returns: new context level
function push_context(    new_level) {
    context_level++
    new_level = context_level
    contexts[new_level]["parent"] = (context_level > 1) ? (context_level - 1) : 0
    return new_level
}

# Pop current context level (exits current scope)
# Returns: previous context level or 0 if stack is empty
function pop_context() {
    if (context_level > 0) {
        delete contexts[context_level]
        context_level--
    }
    return context_level
}

# Get current context level
# Returns: current context level
function get_current_level() {
    return context_level
}

# Set a variable in current context
# Parameters:
#   var_name - variable name
#   value - variable value
function set_var(var_name, value) {
    if (context_level == 0) {
        # No context - create root context
        push_context()
    }
    contexts[context_level]["vars"][var_name] = value
    # CRITICAL: Always sync to ENVIRON for cross-iteration visibility
    # This ensures variables set inside for loops are visible in subsequent iterations
    ENVIRON[var_name] = value
}

# Get a variable value (searches from current context up to root)
# Parameters:
#   var_name - variable name
# Returns: variable value or empty string if not found
function get_var(var_name,    level, parent) {
    level = context_level
    
    # Search from current context up to root
    while (level > 0) {
        if (var_name in contexts[level]["vars"]) {
            return contexts[level]["vars"][var_name]
        }
        # Move to parent context
        if (level in contexts && "parent" in contexts[level]) {
            parent = contexts[level]["parent"]
            level = parent
        } else {
            break
        }
    }
    
    # Not found in contexts - check ENVIRON as fallback
    if (var_name in ENVIRON) {
        return ENVIRON[var_name]
    }
    
    return ""
}

# Check if variable exists in current scope or parent scopes
# Parameters:
#   var_name - variable name
# Returns: 1 if exists, 0 otherwise
function has_var(var_name,    level, parent) {
    level = context_level
    
    # Search from current context up to root
    while (level > 0) {
        if (var_name in contexts[level]["vars"]) {
            return 1
        }
        # Move to parent context
        if (level in contexts && "parent" in contexts[level]) {
            parent = contexts[level]["parent"]
            level = parent
        } else {
            break
        }
    }
    
    # Check ENVIRON as fallback
    if (var_name in ENVIRON) {
        return 1
    }
    
    return 0
}

# Set a variable in a specific context level
# Parameters:
#   level - context level
#   var_name - variable name
#   value - variable value
function set_var_at_level(level, var_name, value) {
    if (level > 0 && level <= context_level) {
        contexts[level]["vars"][var_name] = value
    }
}

# Get a variable value from a specific context level
# Parameters:
#   level - context level
#   var_name - variable name
# Returns: variable value or empty string if not found
function get_var_at_level(level, var_name) {
    if (level > 0 && level <= context_level && var_name in contexts[level]["vars"]) {
        return contexts[level]["vars"][var_name]
    }
    return ""
}

# Clear all contexts (reset stack)
function clear_contexts() {
    delete contexts
    context_level = 0
}

# Export all variables from current context to ENVIRON
# This is useful for compatibility with legacy code that uses ENVIRON
# Exports from all context levels (current and parents)
function export_context_to_environ(    var_name, level, parent) {
    level = context_level
    # Export from all context levels, starting from current down to root
    while (level > 0) {
        if (level in contexts && "vars" in contexts[level]) {
            for (var_name in contexts[level]["vars"]) {
                ENVIRON[var_name] = contexts[level]["vars"][var_name]
            }
        }
        # Move to parent context
        if (level in contexts && "parent" in contexts[level]) {
            parent = contexts[level]["parent"]
            level = parent
        } else {
            break
        }
    }
}

