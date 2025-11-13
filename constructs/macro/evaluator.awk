# MACRO Construct Evaluator
# Evaluates macro constructs: {{#macro NAME}}...{{/macro}}

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/macro_store.awk"
@include "core/construct_registry.awk"

function evaluate_macro(token_id,    macro_name, condition, metadata, content, child_id, child_count, i, child_type, var_name, text_token_id) {
    condition = get_token_metadata(token_id, "condition")
    if (condition == "") {
        return 0
    }
    
    macro_name = condition
    gsub(/^[ \t]+|[ \t]+$/, "", macro_name)
    
    # Get macro content from child tokens BEFORE they are evaluated
    # This preserves template constructs like {{VAR}} and {{#if}} for later expansion
    # We need to render the original children, not evaluated ones
    content = render_macro_children(token_id)
    
    # Store macro (raw template code)
    store_macro(macro_name, content)
    
    # Return empty text token - macro definitions don't produce output
    delete metadata
    text_token_id = create_token("text", "", metadata)
    return text_token_id
}

# Helper function to render macro children recursively
# Universal function that reconstructs template syntax for any construct type
function render_macro_children(parent_id,    result, child_count, i, child_id, child_type, var_name, cond, closing_tag) {
    result = ""
    child_count = get_children_count(parent_id)
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(parent_id, i)
        child_type = get_token_type(child_id)
        
        if (child_type == "text") {
            result = result get_token_value(child_id)
        } else if (child_type == "var") {
            var_name = get_token_metadata(child_id, "var_name")
            result = result "{{" var_name "}}"
        } else if (child_type == "else") {
            result = result "{{else}}"
            result = result render_macro_children(child_id)
        } else if (is_construct_registered(child_type)) {
            # Universal reconstruction for registered constructs
            cond = get_token_metadata(child_id, "condition")
            result = result reconstruct_construct_opening(child_type, cond)
            result = result render_macro_children(child_id)
            result = result reconstruct_construct_closing(child_type)
        } else {
            # Unknown construct type - recurse to get children
            result = result render_macro_children(child_id)
        }
    }
    return result
}

# Reconstruct opening tag for a construct
# Uses construct type and condition to build opening tag
function reconstruct_construct_opening(construct_type, condition,    opening_tag) {
    opening_tag = "{{#" construct_type
    if (condition != "") {
        opening_tag = opening_tag " " condition
    }
    opening_tag = opening_tag "}}"
    return opening_tag
}

# Reconstruct closing tag for a construct
# Uses construct type to build closing tag
function reconstruct_construct_closing(construct_type,    closing_tag) {
    closing_tag = "{{/" construct_type "}}"
    return closing_tag
}

