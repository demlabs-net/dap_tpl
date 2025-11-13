# AWK_SECTION Construct Evaluator
# Evaluates AWK sections: {{AWK: ... }}
# Executes AWK code and outputs generated content

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/renderer.awk"
@include "constructs/text/helpers.awk"
@include "constructs/awk_section/execute_awk_script.awk"

function evaluate_awk_section(token_id,    awk_code, output, text_token_id, metadata, temp_file) {
    # Collect AWK code from children (text tokens)
    awk_code = collect_text_from_children(token_id)
    
    if (awk_code == "") {
        return 0
    }
    
    # Create temporary input file (empty or from ENVIRON if available)
    temp_file = ""
    if ("temp_file" in ENVIRON && ENVIRON["temp_file"] != "") {
        temp_file = ENVIRON["temp_file"]
    }
    
    # Execute AWK code using module function
    output = execute_awk_script_with_input(awk_code, temp_file)
    
    # Create text token with output
    delete metadata
    text_token_id = create_token("text", output, metadata)
    
    return text_token_id
}

