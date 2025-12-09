# Main processing pipeline
# This module handles the main execution flow: tokenize -> evaluate -> render

BEGIN {
    # Initialize random number generator with current time + PID for uniqueness
    # This is critical for parallel builds to avoid temp file collisions
    srand()
    
    # Process template file
    if (ARGC >= 2) {
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
