# SH_SECTION Construct Evaluator
# Evaluates SH sections: {{SH: ... }}
# Executes shell script and outputs generated content

@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/renderer.awk"

function evaluate_sh_section(token_id,    child_count, i, child_id, sh_code, output, text_token_id, metadata, script_file, env_file, wrapper_file, output_file, cmd, line, generated_content, key, value, vars_to_include, env_count) {
    # Collect shell code from children (text tokens)
    sh_code = ""
    child_count = get_children_count(token_id)
    
    for (i = 1; i <= child_count; i++) {
        child_id = get_child(token_id, i)
        if (get_token_type(child_id) == "text") {
            child_text = render_token(child_id)
            if (sh_code != "") {
                sh_code = sh_code "\n"
            }
            sh_code = sh_code child_text
        }
    }
    
    if (sh_code == "") {
        return 0
    }
    
    # Write shell script to temp file
    script_file = "/tmp/sh_script_" NR "_" rand() ".sh"
    print sh_code > script_file
    close(script_file)
    
    # Write environment variables to a file
    env_file = "/tmp/sh_env_" NR "_" rand() ".sh"
    env_count = 0
    
    # Always include these variables if they exist in ENVIRON
    delete vars_to_include
    vars_to_include["CUSTOM_MOCKS_LIST"] = 1
    vars_to_include["WRAPPER_FUNCTIONS"] = 1
    vars_to_include["PARAM_COUNTS_ARRAY"] = 1
    vars_to_include["MAX_ARGS_COUNT"] = 1
    vars_to_include["MISSING_FUNCTIONS"] = 1
    vars_to_include["temp_file"] = 1
    
    for (key in vars_to_include) {
        if (key in ENVIRON && length(ENVIRON[key]) > 0) {
            value = ENVIRON[key]
            # Escape single quotes for shell
            gsub(/'/, "'\\''", value)
            print "export " key "='" value "'" > env_file
            env_count++
        }
    }
    close(env_file)
    
    # Create wrapper script that sources env and executes script
    wrapper_file = "/tmp/sh_wrapper_" NR "_" rand() ".sh"
    print "#!/bin/bash" > wrapper_file
    print ". " env_file > wrapper_file
    print "bash " script_file > wrapper_file
    close(wrapper_file)
    system("chmod +x " wrapper_file)
    
    # Execute wrapper and capture output
    output_file = "/tmp/sh_output_" NR "_" rand() ".txt"
    cmd = wrapper_file " > " output_file " 2>&1"
    system(cmd)
    
    # Read output file
    generated_content = ""
    while ((getline line < output_file) > 0) {
        # Filter debug output lines
        if (line !~ /^\+/ && line !~ /^CUSTOM_MOCKS_LIST=/ && line !~ /^WRAPPER_FUNCTIONS=/ && line !~ /^set -x/ && line !~ /^DEBUG:/ && line != "") {
            if (generated_content != "") {
                generated_content = generated_content "\n"
            }
            generated_content = generated_content line
        }
    }
    close(output_file)
    
    # Cleanup
    system("rm -f " script_file " " env_file " " wrapper_file " " output_file)
    
    # Create text token with output
    delete metadata
    text_token_id = create_token("text", generated_content, metadata)
    
    return text_token_id
}

