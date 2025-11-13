# Construct Registry
# Provides registration and lookup functions for template constructs
# Uses associative arrays for O(1) lookup performance

# Registry structure:
#   CONSTRUCT_PATTERNS[construct_type] = regex_pattern
#   TOKENIZER_FUNCTIONS[construct_type] = function_name
#   EVALUATOR_FUNCTIONS[construct_type] = function_name
#   CLOSING_PATTERNS[closing_tag] = construct_type
#   SPECIAL_MARKERS[construct_type][pattern] = token_type
#   BRANCH_PARSER_FUNCTIONS[construct_type] = function_name
#   BRANCH_MARKER_PATTERNS[construct_type][pattern] = 1
#   CONTENT_PARSER_FUNCTIONS[construct_type] = function_name
#   SELF_CONTAINED_CONSTRUCTS[construct_type] = 1
#   SKIP_EMPTY_TEXT_CONSTRUCTS[construct_type] = 1

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
    SPECIAL_MARKERS[construct_type][pattern] = token_type
    # Also register as branch marker pattern
    BRANCH_MARKER_PATTERNS[construct_type][pattern] = 1
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
function is_branch_marker(construct_type, marker_text,    pattern) {
    if (construct_type in BRANCH_MARKER_PATTERNS) {
        for (pattern in BRANCH_MARKER_PATTERNS[construct_type]) {
            if (match(marker_text, pattern)) {
                return 1
            }
        }
    }
    return 0
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
function get_special_marker_type(construct_type, marker_text,    pattern) {
    if (construct_type in SPECIAL_MARKERS) {
        for (pattern in SPECIAL_MARKERS[construct_type]) {
            if (match(marker_text, pattern)) {
                return SPECIAL_MARKERS[construct_type][pattern]
            }
        }
    }
    return ""
}

