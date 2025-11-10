# Parser for include constructs: {{#include FILE}} - self-contained directive
# Uses marker_detector.awk functions

@include "marker_detector.awk"

# Process include construct marker
function process_include_marker(line, line_num,    condition, remaining, result) {
    result = extract_include_condition(line)
    if (result != "") {
        split(result, parts, "|")
        condition = parts[1]
        remaining = parts[2]
        # Output immediately as self-contained construct (no closing tag)
        print "include|" line_num "|" line_num "|" condition "|" remaining
        return 2  # Return 2 to indicate immediate output
    }
    return 0
}

