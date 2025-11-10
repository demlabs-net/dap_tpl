# Parser for var markers: {{VAR}} - simple variable output
# NOTE: Variables like {{VAR}} should NOT create construct entries
# They are processed directly in replace_template_constructs.awk
# This module is kept for reference but should not output anything

# Process var marker (no-op, variables are processed inline)
function process_var_marker(line, line_num) {
    # Variables are processed directly in replace_template_constructs.awk
    # Do not create construct entries for simple variables
    # They will be replaced inline during variable replacement phase
    return 0
}

