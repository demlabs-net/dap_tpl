# CALL Construct Evaluator
# Evaluates call constructs: {{#call NAME|arg1|arg2}}

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/macro_store.awk"
@include "core/tokenizer_core.awk"

function evaluate_call(token_id,    call_expr, condition, metadata, macro_name, param_count, params, i, parts, n, expanded_content, text_token_id, expanded_root_id, param_name) {
    condition = get_token_metadata(token_id, "condition")
    if (condition == "") {
        return 0
    }
    
    call_expr = condition
    gsub(/^[ \t]+|[ \t]+$/, "", call_expr)
    
    # Parse: NAME|arg1|arg2
    n = split(call_expr, parts, "|")
    if (n < 1) {
        return 0
    }
    
    macro_name = parts[1]
    gsub(/^[ \t]+|[ \t]+$/, "", macro_name)
    
    # Check if macro is defined
    if (!is_macro_defined(macro_name)) {
        print "ERROR: Macro '" macro_name "' is not defined" > "/dev/stderr"
        return 0
    }
    
    # Extract parameters
    param_count = n - 1
    for (i = 2; i <= n; i++) {
        params[i - 2] = parts[i]
        gsub(/^[ \t]+|[ \t]+$/, "", params[i - 2])
    }
    
    # Expand macro (replace {{ARG0}}, {{ARG1}}, etc. with parameter values)
    expanded_content = expand_macro(macro_name, param_count, params)
    
    # Set macro parameters in context
    for (i = 0; i < param_count; i++) {
        param_name = "ARG" i
        set_var(param_name, params[i])
        ENVIRON[param_name] = params[i]
    }
    
    # Tokenize expanded content if it contains template constructs
    if (expanded_content != "" && expanded_content ~ /{{/) {
        expanded_root_id = tokenize(expanded_content)
        if (expanded_root_id > 0) {
            return expanded_root_id
        }
    }
    
    # Return as text token if no template constructs
    delete metadata
    text_token_id = create_token("text", expanded_content, metadata)
    return text_token_id
}

