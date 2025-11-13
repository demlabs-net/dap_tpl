# ROOT Token Definition
# Registers ROOT token renderer in the registry

@include "core/construct_registry.awk"

BEGIN {
    # Register renderer for root tokens
    register_renderer("root", "render_root_token")
}

