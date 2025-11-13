# Marker Utilities
# Basic helper functions for working with markers and positions

# Trim whitespace from both ends of text
# Parameters:
#   text - text to trim
# Returns: trimmed text
function trim(text) {
    gsub(/^[ \t]+|[ \t]+$/, "", text)
    return text
}

# Calculate position after marker (after closing }})
# Parameters:
#   pos - position of {{ marker
#   marker_end - position of }} relative to pos+2
# Returns: absolute position after closing }}
function skip_to_after_marker(pos, marker_end) {
    return pos + 2 + marker_end + 1
}

# Calculate absolute position from relative offset
# Parameters:
#   pos - base position
#   offset - relative offset (1-based)
# Returns: absolute position (0-based)
function calc_absolute_pos(pos, offset) {
    return pos + offset - 1
}

