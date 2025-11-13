# Token Tree Management
# Provides functions for creating and managing AST (Abstract Syntax Tree) of template tokens
# Uses GAWK 5.2.1 true multidimensional arrays: tokens[id]["field"]

# Token structure:
#   tokens[token_id]["type"] - token type: "text", "if", "for", "set", "var", "awk_section"
#   tokens[token_id]["value"] - token value (for text/var tokens)
#   tokens[token_id]["metadata"]["condition"] - condition expression (for if/for/set)
#   tokens[token_id]["metadata"]["var_name"] - variable name (for set/var)
#   tokens[token_id]["metadata"]["start_line"] - starting line number
#   tokens[token_id]["metadata"]["end_line"] - ending line number
#   tokens[token_id]["children"]["count"] - number of child tokens
#   tokens[token_id]["children"][1..N] - child token IDs

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
function create_token(type, value, metadata,    token_id, key) {
    token_id = next_token_id++
    tokens[token_id]["type"] = type
    # Always set value, even if empty (needed for text tokens with empty content)
    tokens[token_id]["value"] = value
    # Copy metadata
    if (isarray(metadata)) {
        for (key in metadata) {
            tokens[token_id]["metadata"][key] = metadata[key]
        }
    }
    return token_id
}

# Add a child token to a parent token
# Parameters:
#   parent_id - parent token ID
#   child_id - child token ID
function add_child(parent_id, child_id) {
    if (!(parent_id in tokens)) {
        return
    }
    if (!("children" in tokens[parent_id])) {
        tokens[parent_id]["children"]["count"] = 0
    }
    tokens[parent_id]["children"]["count"]++
    tokens[parent_id]["children"][tokens[parent_id]["children"]["count"]] = child_id
}

# Get children count for a token
# Parameters:
#   token_id - token ID
# Returns: number of children
function get_children_count(token_id) {
    if (!(token_id in tokens)) {
        return 0
    }
    if (!("children" in tokens[token_id])) {
        return 0
    }
    return tokens[token_id]["children"]["count"]
}

# Get child token ID by index
# Parameters:
#   token_id - parent token ID
#   child_idx - child index (1-based)
# Returns: child token ID or 0 if not found
function get_child(token_id, child_idx) {
    if (!(token_id in tokens)) {
        return 0
    }
    if (!("children" in tokens[token_id])) {
        return 0
    }
    if (child_idx < 1 || child_idx > tokens[token_id]["children"]["count"]) {
        return 0
    }
    return tokens[token_id]["children"][child_idx]
}

# Clone a subtree (deep copy)
# Parameters:
#   token_id - root token ID to clone
# Returns: new root token ID
function clone_subtree(token_id,    new_id, type, value, metadata, child_count, i, child_id, new_child_id, key) {
    if (!(token_id in tokens)) {
        return 0
    }
    
    type = tokens[token_id]["type"]
    value = tokens[token_id]["value"]
    
    # Copy metadata
    delete metadata
    for (key in tokens[token_id]["metadata"]) {
        metadata[key] = tokens[token_id]["metadata"][key]
    }
    
    # Create new token
    new_id = create_token(type, value, metadata)
    
    # Clone children recursively
    child_count = get_children_count(token_id)
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        new_child_id = clone_subtree(child_id)
        if (new_child_id > 0) {
            add_child(new_id, new_child_id)
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
    if (!(token_id in tokens)) {
        return
    }
    
    if (depth == "") {
        depth = 0
    }
    
    # Call callback function using indirect call
    @callback_func(token_id, depth, user_data)
    
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
    if (!(token_id in tokens)) {
        return ""
    }
    return tokens[token_id]["type"]
}

# Get token value
# Parameters:
#   token_id - token ID
# Returns: token value or empty string
function get_token_value(token_id) {
    if (!(token_id in tokens)) {
        return ""
    }
    return tokens[token_id]["value"]
}

# Set token value
# Parameters:
#   token_id - token ID
#   value - new value
function set_token_value(token_id, value) {
    if (token_id in tokens) {
        tokens[token_id]["value"] = value
    }
}

# Get token metadata field
# Parameters:
#   token_id - token ID
#   field - metadata field name
# Returns: metadata value or empty string
function get_token_metadata(token_id, field) {
    if (!(token_id in tokens)) {
        return ""
    }
    if (!(field in tokens[token_id]["metadata"])) {
        return ""
    }
    return tokens[token_id]["metadata"][field]
}

# Set token metadata field
# Parameters:
#   token_id - token ID
#   field - metadata field name
#   value - metadata value
function set_token_metadata(token_id, field, value) {
    if (token_id in tokens) {
        tokens[token_id]["metadata"][field] = value
    }
}

# Check if token exists
# Parameters:
#   token_id - token ID
# Returns: 1 if exists, 0 otherwise
function token_exists(token_id) {
    return (token_id in tokens) ? 1 : 0
}

# Clear all tokens (reset tree)
function clear_token_tree() {
    delete tokens
    next_token_id = 1
}

