# Renderer - Renders evaluated token tree to final text
# Single point of rendering - converts AST to output text
# Uses registry-based callback system for extensible rendering
#
# Supports two modes:
#   1. String mode (default): render_token returns accumulated string
#   2. Streaming mode: render_token prints chunks directly via printf,
#      avoiding large string accumulation that exceeds mawk's sprintf
#      buffer limit (8192 bytes).

@include "core/token_tree.awk"
@include "core/construct_registry.awk"
@include "core/debug.awk"

# Render a token tree to text
# Parameters:
#   token_id - token ID to render
# Returns: rendered text (string mode) or "" (streaming mode, output already printed)
function render_token(token_id,    token_type, renderer_func, result, child_count, i, child_id, child_text, value) {
    if (!token_exists(token_id)) {
        return ""
    }
    
    token_type = get_token_type(token_id)
    
    # Get renderer function from registry
    renderer_func = get_renderer_function(token_type)
    
    if (renderer_func != "") {
        result = @renderer_func(token_id)
        if (_render_stream && result != "") {
            printf "%s", result
            return ""
        }
        return result
    }
    
    # No renderer registered - default behavior: render children
    child_count = get_children_count(token_id)
    if (_render_stream) {
        for (i = 1; i <= child_count; i++) {
            child_id = get_child(token_id, i)
            child_text = render_token(child_id)
            if (child_text != "") {
                printf "%s", child_text
            }
        }
        return ""
    }

    result = ""
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        child_text = render_token(child_id)
        result = result child_text
    }
    
    return result
}

# Render entire tree starting from root (streaming mode)
# Prints output directly to stdout, never accumulates full output in a single
# string. Compatible with mawk and other awk implementations that have limited
# internal sprintf buffers.
# Parameters:
#   root_token_id - root token ID
function render_tree_streaming(root_token_id) {
    _render_stream = 1
    render_token(root_token_id)
    _render_stream = 0
}

# Render entire tree starting from root (string mode)
# Returns the full rendered text as a single string.
# WARNING: May fail on mawk for large templates (>8KB output).
# Use render_tree_streaming for production codegen.
# Parameters:
#   root_token_id - root token ID
# Returns: rendered text
function render_tree(root_token_id,    result, cleaned_result, iterations, marker_start, marker_end, depth, j, pos, original_length, next_char, i) {
    result = render_token(root_token_id)
    
    cleaned_result = result
    original_length = length(cleaned_result)
    
    iterations = 0
    while (iterations < 200) {
        pos = 1
        marker_found = 0
        while (pos <= length(cleaned_result) - 3) {
            if (substr(cleaned_result, pos, 2) == "{{") {
                marker_start = pos
                marker_end = 0
                depth = 0
                for (j = marker_start + 2; j <= length(cleaned_result) - 1; j++) {
                    if (substr(cleaned_result, j, 2) == "{{") {
                        depth++
                        j++
                    } else if (substr(cleaned_result, j, 2) == "}}") {
                        if (depth == 0) {
                            marker_end = j + 1
                            break
                        }
                        depth--
                        j++
                    }
                }
                if (marker_end > 0) {
                    cleaned_result = substr(cleaned_result, 1, marker_start - 1) substr(cleaned_result, marker_end + 1)
                    marker_found = 1
                    break
                } else {
                    cleaned_result = substr(cleaned_result, 1, marker_start - 1)
                    break
                }
            }
            pos++
        }
        if (!marker_found) {
            break
        }
        iterations++
    }
    
    if (length(cleaned_result) != original_length) {
        log_debug("render_tree: removed construct markers and variables, original_length=%d cleaned_length=%d iterations=%d", original_length, length(cleaned_result), iterations)
    }
    
    return cleaned_result
}

