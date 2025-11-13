# TEXT Token Definition
# Registers TEXT token renderer in the registry

@include "core/construct_registry.awk"

BEGIN {
    # Register renderer for text tokens
    register_renderer("text", "render_text_token")
    
    # Register child token processor for text tokens
    register_child_token_processor("text", "process_text_child_token")
    
    # Register text token processor for handling text after newline
    register_text_token_processor("text", "process_text_after_newline")
}

