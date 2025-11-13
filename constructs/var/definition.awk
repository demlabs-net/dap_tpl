# VAR Construct Definition
# Registers VAR construct in the registry
# VAR is a simple variable reference: {{VAR}} or {{VAR|function|args}}

@include "core/construct_registry.awk"

BEGIN {
    # VAR doesn't have opening/closing patterns - it's parsed by tokenizer_core directly
    # Register evaluator
    register_evaluator("var", "evaluate_var")
    
    # Register renderer for var tokens
    register_renderer("var", "render_var_token")
}

