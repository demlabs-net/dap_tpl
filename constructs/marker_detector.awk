# Marker detector for template constructs
# Detects and identifies template construct markers

# Detect if construct marker
function is_construct_marker(line,    marker_type) {
    if (line ~ /{{#if[ \t]/) {
        return "if"
    } else if (line ~ /{{#for[ \t]/) {
        return "for"
    } else if (line ~ /{{#set[ \t]/) {
        return "set"
    } else if (line ~ /{{#include[ \t]/) {
        return "include"
    } else if (line ~ /{{#awk:/) {
        return "awk"
    } else if (line ~ /{{else}}/) {
        return "else"
    } else if (line ~ /{{(\/if|\/for|\/set|\/include)}}/) {
        return "closing"
    } else if (line ~ /^{{}}$/) {
        return "awk_closing"
    }
    return ""
}

# Extract condition from if marker
function extract_if_condition(line,    condition, remaining) {
    if (match(line, /{{#if[ \t]+([^}]+)}}/)) {
        condition = substr(line, RSTART + 6, RLENGTH - 8)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        remaining = line
        sub(/{{#if[ \t]+[^}]+}}/, "", remaining)
        return condition "|" remaining
    } else if (match(line, /{{#if[ \t]+([^}]+)/)) {
        condition = substr(line, RSTART + 6, RLENGTH - 6)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        return condition "|"
    }
    return ""
}

# Extract condition from for marker
function extract_for_condition(line,    condition, remaining) {
    if (match(line, /{{#for[ \t]+([^}]+)}}/)) {
        condition = substr(line, RSTART + 7, RLENGTH - 9)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        remaining = line
        sub(/{{#for[ \t]+[^}]+}}/, "", remaining)
        return condition "|" remaining
    } else if (match(line, /{{#for[ \t]+([^}]+)/)) {
        condition = substr(line, RSTART + 7, RLENGTH - 7)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        return condition "|"
    }
    return ""
}

# Extract condition from set marker
function extract_set_condition(line,    condition, remaining) {
    if (match(line, /{{#set[ \t]+([^}]+)}}/)) {
        condition = substr(line, RSTART + 7, RLENGTH - 9)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        remaining = line
        sub(/{{#set[ \t]+[^}]+}}/, "", remaining)
        return condition "|" remaining
    } else if (match(line, /{{#set[ \t]+([^}]+)/)) {
        condition = substr(line, RSTART + 7, RLENGTH - 7)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        return condition "|"
    }
    return ""
}

# Extract condition from include marker
function extract_include_condition(line,    condition, remaining) {
    if (match(line, /{{#include[ \t]+([^}]+)}}/)) {
        condition = substr(line, RSTART + 10, RLENGTH - 12)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        remaining = line
        sub(/{{#include[ \t]+[^}]+}}/, "", remaining)
        return condition "|" remaining
    } else if (match(line, /{{#include[ \t]+([^}]+)/)) {
        condition = substr(line, RSTART + 10, RLENGTH - 10)
        gsub(/^[ \t]+|[ \t]+$/, "", condition)
        return condition "|"
    }
    return ""
}

# Extract condition from awk marker
function extract_awk_condition(line,    condition, remaining) {
    if (match(line, /{{#awk:(.*)}}/)) {
        condition = substr(line, RSTART + 8, RLENGTH - 10)
        remaining = line
        sub(/{{#awk:[^}]+}}/, "", remaining)
        return condition "|" remaining
    } else if (match(line, /{{#awk:(.*)/)) {
        condition = substr(line, RSTART + 8, RLENGTH - 8)
        return condition "|"
    }
    return ""
}

# Extract closing tag type
function extract_closing_type(line,    closing_type) {
    if (match(line, /{{\/(if|for|set|include)}}/)) {
        closing_type = substr(line, RSTART + 3, RLENGTH - 5)
        return closing_type
    }
    return ""
}

