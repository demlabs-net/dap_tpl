# Token Tree Management
# Provides functions for creating and managing AST (Abstract Syntax Tree) of template tokens
# Uses SUBSEP for multidimensional array simulation

# Token structure (using SUBSEP):
#   tokens[token_id SUBSEP "type"] - token type: "text", "if", "for", "set", "var", "awk_section"
#   tokens[token_id SUBSEP "value"] - token value (for text/var tokens)
#   tokens[token_id SUBSEP "metadata" SUBSEP "condition"] - condition expression (for if/for/set)
#   tokens[token_id SUBSEP "metadata" SUBSEP "var_name"] - variable name (for set/var)
#   tokens[token_id SUBSEP "metadata" SUBSEP "start_line"] - starting line number
#   tokens[token_id SUBSEP "metadata" SUBSEP "end_line"] - ending line number
#   tokens[token_id SUBSEP "children" SUBSEP "count"] - number of child tokens
#   tokens[token_id SUBSEP "children" SUBSEP 1..N] - child token IDs

BEGIN {
    # Global token counter
    next_token_id = 1
}

# Create a new token and return its ID
# Parameters:
#   type - token type: "text", "if", "for", "set", "var", "awk_section"
#   value - token value (optional, for text/var tokens)
#   metadata - associative array with metadata (condition, var_name, start_line, end_line)
# Returns: token ID
# NODISPATCH: takes array parameter
function create_token(type, value, metadata,    token_id, key) {
    token_id = next_token_id++
    tokens[token_id SUBSEP "type"] = type
    # Always set value, even if empty (needed for text tokens with empty content)
    tokens[token_id SUBSEP "value"] = value
    # Copy metadata - for-in loop safely handles undefined arrays
    for (key in metadata) {
        tokens[token_id SUBSEP "metadata" SUBSEP key] = metadata[key]
    }
    return token_id
}

# Add a child token to a parent token
# Parameters:
#   parent_id - parent token ID
#   child_id - child token ID
function add_child(parent_id, child_id) {
    if (!((parent_id SUBSEP "type") in tokens)) {
        return
    }
    if (!((parent_id SUBSEP "children" SUBSEP "count") in tokens)) {
        tokens[parent_id SUBSEP "children" SUBSEP "count"] = 0
    }
    tokens[parent_id SUBSEP "children" SUBSEP "count"]++
    tokens[parent_id SUBSEP "children" SUBSEP tokens[parent_id SUBSEP "children" SUBSEP "count"]] = child_id
}

# Get children count for a token
# Parameters:
#   token_id - token ID
# Returns: number of children
function get_children_count(token_id) {
    if (!((token_id SUBSEP "type") in tokens)) {
        return 0
    }
    if (!((token_id SUBSEP "children" SUBSEP "count") in tokens)) {
        return 0
    }
    return tokens[token_id SUBSEP "children" SUBSEP "count"]
}

# Get child token ID by index
# Parameters:
#   token_id - parent token ID
#   child_idx - child index (1-based)
# Returns: child token ID or 0 if not found
function get_child(token_id, child_idx) {
    if (!((token_id SUBSEP "type") in tokens)) {
        return 0
    }
    if (!((token_id SUBSEP "children" SUBSEP "count") in tokens)) {
        return 0
    }
    if (child_idx < 1 || child_idx > tokens[token_id SUBSEP "children" SUBSEP "count"]) {
        return 0
    }
    return tokens[token_id SUBSEP "children" SUBSEP child_idx]
}

# Clone a subtree (deep copy)
# Parameters:
#   token_id - root token ID to clone
# Returns: new root token ID
function clone_subtree(token_id,    new_id, type, value, metadata, child_count, i, child_id, new_child_id, key, condition) {
    if (!((token_id SUBSEP "type") in tokens)) {
        return 0
    }
    
    type = tokens[token_id SUBSEP "type"]
    value = tokens[token_id SUBSEP "value"]
    
    # Copy metadata
    delete metadata
    for (key in tokens) {
        # Extract metadata keys for this token_id
        if (index(key, token_id SUBSEP "metadata" SUBSEP) == 1) {
            # Extract the field name after "metadata" SUBSEP
            field = substr(key, length(token_id SUBSEP "metadata" SUBSEP) + 1)
            metadata[field] = tokens[key]
        }
    }
    
    # Create new token
    new_id = create_token(type, value, metadata)
    
    # Clone children recursively
    child_count = get_children_count(token_id)
    
    # Debug output for if tokens with type == 'void' condition
    if (type == "if") {
        condition = tokens[token_id SUBSEP "metadata" SUBSEP "condition"]
        if (condition ~ /type.*==.*void/) {
            log_debug("clone_subtree: BEFORE clone, token_id=%d type=%s children=%d condition=[%s]\n", token_id, type, child_count, condition)
        }
    }
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        new_child_id = clone_subtree(child_id)
        if (new_child_id > 0) {
            add_child(new_id, new_child_id)
        }
    }
    
    # Debug output for if tokens with type == 'void' condition
    if (type == "if") {
        condition = metadata["condition"]
        if (condition ~ /type.*==.*void/) {
            log_debug("clone_subtree: AFTER clone, new_id=%d type=%s children=%d condition=[%s]\n", new_id, type, get_children_count(new_id), condition)
        }
    }
    
    return new_id
}

# Traverse tree and call callback function for each token
# Parameters:
#   token_id - root token ID
#   callback_func - function name to call (as string)
#   user_data - optional user data to pass to callback
#   depth - current depth (internal, starts at 0)
function traverse_tree(token_id, callback_func, user_data, depth,    child_count, i, child_id) {
    if (!((token_id SUBSEP "type") in tokens)) {
        return
    }
    
    if (depth == "") {
        depth = 0
    }
    
    # Call callback function using dispatch
    dispatch_3(callback_func, token_id, depth, user_data)
    
    # Traverse children
    child_count = get_children_count(token_id)
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        traverse_tree(child_id, callback_func, user_data, depth + 1)
    }
}

# Get token type
# Parameters:
#   token_id - token ID
# Returns: token type or empty string
function get_token_type(token_id) {
    if (!((token_id SUBSEP "type") in tokens)) {
        return ""
    }
    return tokens[token_id SUBSEP "type"]
}

# Get token value
# Parameters:
#   token_id - token ID
# Returns: token value or empty string
function get_token_value(token_id) {
    if (!((token_id SUBSEP "type") in tokens)) {
        return ""
    }
    return tokens[token_id SUBSEP "value"]
}

# Set token value
# Parameters:
#   token_id - token ID
#   value - new value
function set_token_value(token_id, value) {
    if ((token_id SUBSEP "type") in tokens) {
        tokens[token_id SUBSEP "value"] = value
    }
}

# Get token metadata field
# Parameters:
#   token_id - token ID
#   field - metadata field name
# Returns: metadata value or empty string
function get_token_metadata(token_id, field,    key) {
    if (!((token_id SUBSEP "type") in tokens)) {
        return ""
    }
    key = token_id SUBSEP "metadata" SUBSEP field
    if (!(key in tokens)) {
        return ""
    }
    return tokens[key]
}

# Set token metadata field
# Parameters:
#   token_id - token ID
#   field - metadata field name
#   value - metadata value
function set_token_metadata(token_id, field, value) {
    if ((token_id SUBSEP "type") in tokens) {
        tokens[token_id SUBSEP "metadata" SUBSEP field] = value
    }
}

# Check if token exists
# Parameters:
#   token_id - token ID
# Returns: 1 if exists, 0 otherwise
function token_exists(token_id) {
    # Tokens stored with SUBSEP: token_id SUBSEP "type"
    return ((token_id SUBSEP "type") in tokens) ? 1 : 0
}

# Clear all tokens (reset tree)
function clear_token_tree() {
    delete tokens
    next_token_id = 1
}

