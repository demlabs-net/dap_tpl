# DAP TPL Engine - Main orchestrator
# Pipeline: tokenize → evaluate → render

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/tokenizer.awk"
@include "core/evaluator.awk"
@include "core/renderer.awk"

BEGIN {
    # Main processing pipeline
    if (ARGC >= 2) {
        # Process template file
        template_file = ARGV[1]
        
        # Tokenize
        root_token_id = tokenize_file(template_file)
        
        if (root_token_id == 0) {
            print "ERROR: Failed to tokenize template" > "/dev/stderr"
            exit 1
        }
        
        # Evaluate
        evaluated_token_id = evaluate_tree(root_token_id)
        
        if (evaluated_token_id == 0) {
            print "ERROR: Failed to evaluate template" > "/dev/stderr"
            exit 1
        }
        
        # Render
        output_text = render_tree(evaluated_token_id)
        
        # Output result
        print output_text
    } else {
        # Read from stdin
        template_text = ""
        while ((getline line) > 0) {
            if (template_text != "") {
                template_text = template_text "\n"
            }
            template_text = template_text line
        }
        
        if (template_text == "") {
            print "ERROR: No template input provided" > "/dev/stderr"
            exit 1
        }
        
        # Tokenize
        root_token_id = tokenize(template_text)
        
        if (root_token_id == 0) {
            print "ERROR: Failed to tokenize template" > "/dev/stderr"
            exit 1
        }
        
        # Evaluate
        evaluated_token_id = evaluate_tree(root_token_id)
        
        if (evaluated_token_id == 0) {
            print "ERROR: Failed to evaluate template" > "/dev/stderr"
            exit 1
        }
        
        # Render
        output_text = render_tree(evaluated_token_id)
        
        # Output result
        print output_text
    }
}

