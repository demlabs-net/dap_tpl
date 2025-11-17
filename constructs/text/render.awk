# Text Token Renderer
# Renders text tokens - returns value directly
# Also replaces variables {{VAR}} in text content

@include "core/token_tree.awk"
@include "core/debug.awk"
@include "core/variable_replacer.awk"

# Render a text token
# Parameters:
#   token_id - token ID to render
# Returns: rendered text (token value)
function render_text_token(token_id,    value, replaced_value, cleaned_value, iterations, marker_start, marker_end, depth, i, pos, marker_found) {
    value = get_token_value(token_id)
    
    # Debug output disabled by default - use DEBUG_ENABLED to enable
    # if (DEBUG_ENABLED && value ~ /\n/ && length(value) > 1) {
    #     log_debug("render_text_token: START token_id=%d value=[%s] value_length=%d", token_id, value, length(value))
    # }
    
    # Remove construct markers ({{#if}}, {{#set}}, {{/if}}, etc.) that shouldn't be in output
    # These should have been processed during tokenization, but if they appear in text tokens,
    # they need to be removed to prevent them from appearing in final output
    cleaned_value = value
    iterations = 0
    
    # Remove construct markers: {{#...}} and {{/...}} (including multiline)
    # Use multiple passes to ensure all markers are removed
    while (iterations < 100) {
        pos = 1
        marker_found = 0
        while (pos <= length(cleaned_value) - 3) {
            if (substr(cleaned_value, pos, 2) == "{{") {
                marker_start = pos
                marker_end = 0
                depth = 0
                # Find matching }} accounting for nested markers
                for (i = marker_start + 2; i <= length(cleaned_value) - 1; i++) {
                    if (substr(cleaned_value, i, 2) == "{{") {
                        depth++
                        i++  # Skip second {
                    } else if (substr(cleaned_value, i, 2) == "}}") {
                        if (depth == 0) {
                            marker_end = i + 1  # Position after }}
                            break
                        }
                        depth--
                        i++  # Skip second }
                    }
                }
                if (marker_end > 0) {
                    cleaned_value = substr(cleaned_value, 1, marker_start - 1) substr(cleaned_value, marker_end + 1)
                    marker_found = 1
                    break  # Restart from beginning after removal
                } else {
                    # No matching }} found - remove from marker_start to end
                    cleaned_value = substr(cleaned_value, 1, marker_start - 1)
                    break
                }
            }
            pos++
        }
        if (!marker_found) {
            break  # No more markers found
        }
        iterations++
    }
    
    # After removing construct markers, check if there are any remaining markers
    # If there are variable markers, replace them
    # If there are still construct markers, remove them again (safety net)
    if (cleaned_value ~ /{{/) {
        # Check if there are variable markers (not construct markers)
        if (cleaned_value ~ /{{[^#\/][^}]*}}/) {
            replaced_value = replace_variables(cleaned_value)
            # After replacing variables, check again for any remaining markers
            if (replaced_value ~ /{{/) {
                # Still have markers - remove them (they shouldn't be here)
                final_cleaned = replaced_value
                final_iterations = 0
                while (final_iterations < 100 && final_cleaned ~ /{{/) {
                    final_pos = 1
                    final_marker_found = 0
                    while (final_pos <= length(final_cleaned) - 3) {
                        if (substr(final_cleaned, final_pos, 2) == "{{") {
                            final_marker_start = final_pos
                            final_marker_end = 0
                            final_depth = 0
                            for (final_i = final_marker_start + 2; final_i <= length(final_cleaned) - 1; final_i++) {
                                if (substr(final_cleaned, final_i, 2) == "{{") {
                                    final_depth++
                                    final_i++
                                } else if (substr(final_cleaned, final_i, 2) == "}}") {
                                    if (final_depth == 0) {
                                        final_marker_end = final_i + 1
                                        break
                                    }
                                    final_depth--
                                    final_i++
                                }
                            }
                            if (final_marker_end > 0) {
                                final_cleaned = substr(final_cleaned, 1, final_marker_start - 1) substr(final_cleaned, final_marker_end + 1)
                                final_marker_found = 1
                                break
                            } else {
                                final_cleaned = substr(final_cleaned, 1, final_marker_start - 1)
                                break
                            }
                        }
                        final_pos++
                    }
                    if (!final_marker_found) {
                        break
                    }
                    final_iterations++
                }
                log_debug("render_text_token: token_id=%d replaced variables and removed remaining markers, original=[%s] cleaned=[%s] replaced=[%s] final=[%s]", token_id, value, cleaned_value, replaced_value, final_cleaned)
                return final_cleaned
            }
            log_debug("render_text_token: token_id=%d replaced variables, original=[%s] cleaned=[%s] replaced=[%s]", token_id, value, cleaned_value, replaced_value)
            return replaced_value
        } else {
            # Still have construct markers - remove them
            final_cleaned = cleaned_value
            final_iterations = 0
            while (final_iterations < 100 && final_cleaned ~ /{{/) {
                final_pos = 1
                final_marker_found = 0
                while (final_pos <= length(final_cleaned) - 3) {
                    if (substr(final_cleaned, final_pos, 2) == "{{") {
                        final_marker_start = final_pos
                        final_marker_end = 0
                        final_depth = 0
                        for (final_i = final_marker_start + 2; final_i <= length(final_cleaned) - 1; final_i++) {
                            if (substr(final_cleaned, final_i, 2) == "{{") {
                                final_depth++
                                final_i++
                            } else if (substr(final_cleaned, final_i, 2) == "}}") {
                                if (final_depth == 0) {
                                    final_marker_end = final_i + 1
                                    break
                                }
                                final_depth--
                                final_i++
                            }
                        }
                        if (final_marker_end > 0) {
                            final_cleaned = substr(final_cleaned, 1, final_marker_start - 1) substr(final_cleaned, final_marker_end + 1)
                            final_marker_found = 1
                            break
                        } else {
                            final_cleaned = substr(final_cleaned, 1, final_marker_start - 1)
                            break
                        }
                    }
                    final_pos++
                }
                if (!final_marker_found) {
                    break
                }
                final_iterations++
            }
            log_debug("render_text_token: token_id=%d removed remaining construct markers, original=[%s] cleaned=[%s] final=[%s]", token_id, value, cleaned_value, final_cleaned)
            return final_cleaned
        }
    }
    
    if (cleaned_value != value) {
        log_debug("render_text_token: token_id=%d removed construct markers, original=[%s] cleaned=[%s]", token_id, value, cleaned_value)
        # Debug output disabled by default - use DEBUG_ENABLED to enable
        # if (DEBUG_ENABLED && length(value) > 0 && length(cleaned_value) == 0) {
        #     log_debug("render_text_token: WARNING token_id=%d cleaned_value is EMPTY after marker removal, original=[%s] original_length=%d", token_id, value, length(value))
        # }
        return cleaned_value
    }
    
    # Debug output disabled by default - use DEBUG_ENABLED to enable
    # if (DEBUG_ENABLED && value ~ /\n/ && length(value) > 1) {
    #     log_debug("render_text_token: RETURN token_id=%d value=[%s] value_length=%d", token_id, value, length(value))
    # }
    
    return value
}

