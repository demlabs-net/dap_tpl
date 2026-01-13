# Construct Registry
# Provides registration and lookup functions for template constructs
# Uses SUBSEP for multidimensional array simulation

# Registry structure (using SUBSEP for 2D arrays):
#   CONSTRUCT_PATTERNS[construct_type] = regex_pattern
#   TOKENIZER_FUNCTIONS[construct_type] = function_name
#   EVALUATOR_FUNCTIONS[construct_type] = function_name
#   RENDERER_FUNCTIONS[token_type] = function_name
#   CLOSING_PATTERNS[closing_tag] = construct_type
#   SPECIAL_MARKERS[construct_type SUBSEP pattern] = token_type
#   BRANCH_PARSER_FUNCTIONS[construct_type] = function_name
#   BRANCH_MARKER_PATTERNS[construct_type SUBSEP pattern] = 1
#   CONTENT_PARSER_FUNCTIONS[construct_type] = function_name
#   SELF_CONTAINED_CONSTRUCTS[construct_type] = 1
#   SKIP_EMPTY_TEXT_CONSTRUCTS[construct_type] = 1
#   TEXT_TOKEN_FILTERS[construct_type] = function_name
#   TEXT_TOKEN_PROCESSORS[token_type] = function_name
#   CHILD_TOKEN_PROCESSORS[token_type] = function_name

BEGIN {
    # Initialize registry arrays
    # These will be populated by definition.awk files
}

# Register an opening pattern for a construct
# Parameters:
#   construct_type - type name (e.g., "if", "for")
#   pattern - regex pattern to match opening marker
#   tokenizer_func - name of tokenizer function
function register_opening_pattern(construct_type, pattern, tokenizer_func) {
    CONSTRUCT_PATTERNS[construct_type] = pattern
    TOKENIZER_FUNCTIONS[construct_type] = tokenizer_func
}

# Register a closing pattern for a construct
# Parameters:
#   construct_type - type name
#   closing_tag - closing tag pattern (e.g., "^/if$")
function register_closing_pattern(construct_type, closing_tag) {
    CLOSING_PATTERNS[closing_tag] = construct_type
}

# Register a special marker (like "else" for "if")
# Parameters:
#   construct_type - parent construct type
#   pattern - regex pattern for special marker
#   token_type - token type for this marker
function register_special_marker(construct_type, pattern, token_type) {
    SPECIAL_MARKERS[construct_type SUBSEP pattern] = token_type
    # Also register as branch marker pattern
    BRANCH_MARKER_PATTERNS[construct_type SUBSEP pattern] = 1
}

# Register a branch parser function for a construct
# This function will be called to parse branches (elif/else) within the construct
# Parameters:
#   construct_type - construct type
#   parser_func - function name that takes (content, token_id, start_line) and parses branches
function register_branch_parser(construct_type, parser_func) {
    BRANCH_PARSER_FUNCTIONS[construct_type] = parser_func
}

# Check if a marker is a branch marker for a construct
# Parameters:
#   construct_type - construct type
#   marker_text - marker text
# Returns: 1 if branch marker, 0 otherwise
function is_branch_marker(construct_type, marker_text,    key, pattern, prefix) {
    # Iterate through all BRANCH_MARKER_PATTERNS keys that start with construct_type
    prefix = construct_type SUBSEP
    for (key in BRANCH_MARKER_PATTERNS) {
        if (index(key, prefix) == 1) {
            # Extract pattern from key
            pattern = substr(key, length(prefix) + 1)
            if (match(marker_text, pattern)) {
                return 1
            }
        }
    }
    return 0
}

# Register a text token processor callback
# Used for processing text tokens during rendering (e.g., removing whitespace after set tokens)
# Parameters:
#   token_type - token type that should trigger processing (e.g., "set")
#   processor_func - function name that takes (text_value, prev_token_type, prev_token_value, next_token_type) and returns processed value or "SKIP"
function register_text_token_processor(token_type, processor_func) {
    TEXT_TOKEN_PROCESSORS[token_type] = processor_func
}

# Get text token processor for a token type
# Parameters:
#   token_type - token type
# Returns: processor function name or empty string
function get_text_token_processor(token_type) {
    if (token_type in TEXT_TOKEN_PROCESSORS) {
        return TEXT_TOKEN_PROCESSORS[token_type]
    }
    return ""
}

# Process text token using registered processors
# Checks if previous token has a processor and applies it
# Parameters:
#   text_value - text token value
#   prev_token_type - previous token type (or empty string)
#   prev_token_value - previous token rendered value (or empty string)
#   next_token_type - next token type (or empty string)
# Returns: "SKIP" to skip token, modified text value, or empty string to keep original
function process_text_token(text_value, prev_token_type, prev_token_value, next_token_type,    processor_func, result) {
    # Check previous token processor
    if (prev_token_type != "") {
        processor_func = get_text_token_processor(prev_token_type)
        if (processor_func != "") {
            # Use indirect function call (GNU AWK feature)
            result = @processor_func(text_value, prev_token_type, prev_token_value, next_token_type)
            if (result == "SKIP") {
                return "SKIP"
            } else if (result != "" && result != text_value) {
                # Processor returned modified value - use it
                return result
            }
        }
    }
    
    # Return empty string to indicate no change (keep original)
    return ""
}

# Register a child token processor callback
# Used for processing child tokens during rendering (e.g., text token filtering)
# Parameters:
#   token_type - token type that should trigger processing (e.g., "text")
#   processor_func - function name that takes (child_text, child_type, prev_token_type, prev_token_value, next_token_type) and returns processed value or "SKIP"
function register_child_token_processor(token_type, processor_func) {
    CHILD_TOKEN_PROCESSORS[token_type] = processor_func
}

# Get child token processor for a token type
# Parameters:
#   token_type - token type
# Returns: processor function name or empty string
function get_child_token_processor(token_type) {
    if (token_type in CHILD_TOKEN_PROCESSORS) {
        return CHILD_TOKEN_PROCESSORS[token_type]
    }
    return ""
}

# Process child token using registered processors
# Checks if token type has a processor and applies it
# Parameters:
#   child_text - child token rendered text
#   child_type - child token type
#   prev_token_type - previous token type (or empty string)
#   prev_token_value - previous token rendered value (or empty string)
#   next_token_type - next token type (or empty string)
# Returns: "SKIP" to skip token, modified text value, or empty string to keep original
function process_child_token(child_text, child_type, prev_token_type, prev_token_value, next_token_type,    processor_func, result) {
    # Check if token type has a processor
    processor_func = get_child_token_processor(child_type)
    if (processor_func != "") {
        # Use indirect function call (GNU AWK feature)
        result = @processor_func(child_text, child_type, prev_token_type, prev_token_value, next_token_type)
        if (result == "SKIP") {
            return "SKIP"
        } else if (result != "" && result != child_text) {
            # Processor returned modified value - use it
            return result
        }
    }
    
    # Return empty string to indicate no change (keep original)
    return ""
}

# Get branch parser function for a construct
# Parameters:
#   construct_type - construct type
# Returns: function name or empty string
function get_branch_parser(construct_type) {
    if (construct_type in BRANCH_PARSER_FUNCTIONS) {
        return BRANCH_PARSER_FUNCTIONS[construct_type]
    }
    return ""
}

# Register a content parser function for a construct
# This function handles special content parsing (like multi-line comments)
# Parameters:
#   construct_type - construct type
#   parser_func - function name that takes (content, start_pos, token_id) and returns end_pos
function register_content_parser(construct_type, parser_func) {
    CONTENT_PARSER_FUNCTIONS[construct_type] = parser_func
}

# Get content parser function for a construct
# Parameters:
#   construct_type - construct type
# Returns: function name or empty string
function get_content_parser(construct_type) {
    if (construct_type in CONTENT_PARSER_FUNCTIONS) {
        return CONTENT_PARSER_FUNCTIONS[construct_type]
    }
    return ""
}

# Mark a construct as self-contained (doesn't need closing tag)
# Parameters:
#   construct_type - construct type
function register_self_contained(construct_type) {
    SELF_CONTAINED_CONSTRUCTS[construct_type] = 1
}

# Check if a construct is self-contained
# Parameters:
#   construct_type - construct type
# Returns: 1 if self-contained, 0 otherwise
function is_self_contained(construct_type) {
    return (construct_type in SELF_CONTAINED_CONSTRUCTS) ? 1 : 0
}

# Mark a construct to skip empty text tokens when rendering
# This is useful for constructs like comments that produce empty text tokens
# Parameters:
#   construct_type - construct type
function register_skip_empty_text(construct_type) {
    SKIP_EMPTY_TEXT_CONSTRUCTS[construct_type] = 1
}

# Check if a construct should skip empty text tokens when rendering
# Parameters:
#   construct_type - construct type
# Returns: 1 if should skip, 0 otherwise
function should_skip_empty_text(construct_type) {
    return (construct_type in SKIP_EMPTY_TEXT_CONSTRUCTS) ? 1 : 0
}

# Register an evaluator function for a construct
# Parameters:
#   construct_type - type name
#   evaluator_func - name of evaluator function
function register_evaluator(construct_type, evaluator_func) {
    EVALUATOR_FUNCTIONS[construct_type] = evaluator_func
}

# Register a renderer function for a token type
# Parameters:
#   token_type - token type name (e.g., "text", "var", "set", "root")
#   renderer_func - name of renderer function that takes token_id and returns rendered text
function register_renderer(token_type, renderer_func) {
    RENDERER_FUNCTIONS[token_type] = renderer_func
}

# Get renderer function for a token type
# Parameters:
#   token_type - token type name
# Returns: function name or empty string
function get_renderer_function(token_type) {
    if (token_type in RENDERER_FUNCTIONS) {
        return RENDERER_FUNCTIONS[token_type]
    }
    return ""
}

# Check if a construct type is registered
# Parameters:
#   construct_type - type name
# Returns: 1 if registered, 0 otherwise
function is_construct_registered(construct_type) {
    return (construct_type in CONSTRUCT_PATTERNS)
}

# Get tokenizer function for a construct type
# Parameters:
#   construct_type - type name
# Returns: function name or empty string
function get_tokenizer_function(construct_type) {
    if (construct_type in TOKENIZER_FUNCTIONS) {
        return TOKENIZER_FUNCTIONS[construct_type]
    }
    return ""
}

# Get evaluator function for a construct type
# Parameters:
#   construct_type - type name
# Returns: function name or empty string
function get_evaluator_function(construct_type) {
    if (construct_type in EVALUATOR_FUNCTIONS) {
        return EVALUATOR_FUNCTIONS[construct_type]
    }
    return ""
}

# Check if a closing tag matches a registered construct
# Parameters:
#   closing_tag - closing tag text (e.g., "/if")
# Returns: construct type or empty string
function get_construct_for_closing(closing_tag) {
    if (closing_tag in CLOSING_PATTERNS) {
        return CLOSING_PATTERNS[closing_tag]
    }
    return ""
}

# Check if a marker is a special marker for a construct
# Parameters:
#   construct_type - parent construct type
#   marker_text - marker text to check
# Returns: token type or empty string
function get_special_marker_type(construct_type, marker_text,    key, pattern, prefix) {
    # Iterate through all SPECIAL_MARKERS keys that start with construct_type
    prefix = construct_type SUBSEP
    for (key in SPECIAL_MARKERS) {
        if (index(key, prefix) == 1) {
            # Extract pattern from key
            pattern = substr(key, length(prefix) + 1)
            if (match(marker_text, pattern)) {
                return SPECIAL_MARKERS[key]
            }
        }
    }
    return ""
}

# Register a marker processor callback
# Used for processing special markers like {{AWK:...}} in variable expressions
# Parameters:
#   marker_prefix - prefix to match (e.g., "AWK:")
#   processor_func - function name that takes marker_text and returns processed value
function register_marker_processor(marker_prefix, processor_func) {
    MARKER_PROCESSORS[marker_prefix] = processor_func
}

# Register a marker processor by pattern
# Parameters:
#   pattern - regex pattern to match marker text
#   processor_func - function name that takes marker_text and returns processed value
function register_marker_processor_pattern(pattern, processor_func) {
    MARKER_PROCESSOR_PATTERNS[pattern] = processor_func
}

# Process a marker using registered processors
# Checks prefix-based processors first, then pattern-based
# Parameters:
#   marker_text - marker content (without {{ and }})
# Returns: processed value or empty string if no processor found
function process_marker(marker_text,    prefix, processor_func, pattern, result) {
    # Try prefix-based processors first
    for (prefix in MARKER_PROCESSORS) {
        if (substr(marker_text, 1, length(prefix)) == prefix) {
            processor_func = MARKER_PROCESSORS[prefix]
            # Use indirect function call (GNU AWK feature)
            result = @processor_func(marker_text)
            if (result != "") {
                return result
            }
        }
    }
    
    # Try pattern-based processors
    for (pattern in MARKER_PROCESSOR_PATTERNS) {
        if (match(marker_text, pattern)) {
            processor_func = MARKER_PROCESSOR_PATTERNS[pattern]
            # Use indirect function call (GNU AWK feature)
            result = @processor_func(marker_text)
            if (result != "") {
                return result
            }
        }
    }
    
    return ""
}

# Register a text token filter callback
# Used for filtering text tokens around constructs (e.g., skip whitespace around set)
# Parameters:
#   construct_type - construct type that should filter text tokens
#   filter_func - function name that takes (text_token_value, prev_token_type, next_token_type) and returns 1 to skip, 0 to keep
function register_text_token_filter(construct_type, filter_func) {
    TEXT_TOKEN_FILTERS[construct_type] = filter_func
}

# Check if a construct has a text token filter registered
# Parameters:
#   construct_type - construct type
# Returns: filter function name or empty string
function get_text_token_filter(construct_type) {
    if (construct_type in TEXT_TOKEN_FILTERS) {
        return TEXT_TOKEN_FILTERS[construct_type]
    }
    return ""
}

# Process text token using registered filters
# Checks if previous or next token has a filter and applies it
# Parameters:
#   text_value - text token value
#   prev_token_type - previous token type (or empty string)
#   prev_token_value - previous token value (for checking if it's just newline)
#   next_token_type - next token type (or empty string)
# Returns: "SKIP" to skip token, modified text value, or empty string to keep original
function filter_text_token(text_value, prev_token_type, prev_token_value, next_token_type,    filter_func, result, modified_value) {
    # Check previous token filter
    if (prev_token_type != "") {
        filter_func = get_text_token_filter(prev_token_type)
        if (filter_func != "") {
            # Use indirect function call (GNU AWK feature)
            # Filter can return:
            #   "SKIP" - skip token entirely
            #   modified text value - use modified value
            #   empty string - keep original value
            modified_value = @filter_func(text_value, prev_token_type, next_token_type)
            if (modified_value == "SKIP") {
                return "SKIP"
            } else if (modified_value != "" && modified_value != text_value) {
                # Filter modified the value - use it
                text_value = modified_value
            }
        }
    }
    
    # Special case: if previous token is text with only newline, and we need to check
    # if the token before that was set, we need to pass prev_token_value
    # For now, handle this in the filter function itself
    
    # Check next token filter
    if (next_token_type != "") {
        filter_func = get_text_token_filter(next_token_type)
        if (filter_func != "") {
            # Use indirect function call (GNU AWK feature)
            modified_value = @filter_func(text_value, prev_token_type, next_token_type)
            if (modified_value == "SKIP") {
                return "SKIP"
            } else if (modified_value != "" && modified_value != text_value) {
                # Filter modified the value - use it
                text_value = modified_value
            }
        }
    }
    
    # Return empty string to indicate no change (keep original)
    return ""
}

