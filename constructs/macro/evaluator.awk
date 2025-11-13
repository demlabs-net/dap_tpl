# MACRO Construct Evaluator
# Evaluates macro constructs: {{#macro NAME}}...{{/macro}}

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/macro_store.awk"

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
    content = ""
    child_count = get_children_count(token_id)
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        if (child_id > 0) {
            child_type = get_token_type(child_id)
            if (child_type == "text") {
                content = content get_token_value(child_id)
            } else if (child_type == "var") {
                var_name = get_token_metadata(child_id, "var_name")
                content = content "{{" var_name "}}"
            } else if (child_type == "if") {
                # Reconstruct if syntax
                cond = get_token_metadata(child_id, "condition")
                content = content "{{#if " cond "}}"
                # Render children recursively
                content = content render_macro_children(child_id)
                content = content "{{/if}}"
            } else if (child_type == "for") {
                # Reconstruct for syntax
                cond = get_token_metadata(child_id, "condition")
                content = content "{{#for " cond "}}"
                content = content render_macro_children(child_id)
                content = content "{{/for}}"
            } else {
                # Other constructs - skip or handle similarly
                # For now, just get text content
                content = content render_macro_children(child_id)
            }
        }
    }
    
    # Store macro (raw template code)
    store_macro(macro_name, content)
    
    # Return empty text token - macro definitions don't produce output
    delete metadata
    text_token_id = create_token("text", "", metadata)
    return text_token_id
}

# Helper function to render macro children recursively
function render_macro_children(parent_id,    result, child_count, i, child_id, child_type, var_name, cond) {
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
        } else if (child_type == "if") {
            cond = get_token_metadata(child_id, "condition")
            result = result "{{#if " cond "}}"
            result = result render_macro_children(child_id)
            result = result "{{/if}}"
        } else if (child_type == "for") {
            cond = get_token_metadata(child_id, "condition")
            result = result "{{#for " cond "}}"
            result = result render_macro_children(child_id)
            result = result "{{/for}}"
        } else if (child_type == "else") {
            result = result "{{else}}"
            result = result render_macro_children(child_id)
        } else {
            # Other types - recurse
            result = result render_macro_children(child_id)
        }
    }
    return result
}

