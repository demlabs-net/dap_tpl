# Module for executing AWK scripts with input file support
# Provides function execute_awk_script_with_input() for running AWK scripts
# Also provides process_awk_marker() for processing AWK markers in variable expressions

# Process AWK section marker in variable expressions
# Parameters:
#   marker_text - marker content (e.g., "AWK:\nBEGIN { ... }")
# Returns: AWK script output or empty string on error
function process_awk_marker(marker_text,    awk_code, awk_output) {
    # Check if this is an AWK section
    if (substr(marker_text, 1, 4) != "AWK:") {
        return ""
    }
    
    # Extract AWK code (everything after "AWK:")
    awk_code = substr(marker_text, 5)
    gsub(/^[ \t\n]+|[ \t\n]+$/, "", awk_code)  # trim
    
    if (awk_code == "") {
        return ""
    }
    
    # Execute AWK code using execute_awk_script_with_input
    awk_output = execute_awk_script_with_input(awk_code, "")
    
    return awk_output
}

# Function to execute AWK script with input file and environment variables
# Parameters:
#   script_code - AWK script code to execute
#   input_file - input file to pass to AWK script (optional, can be "")
#   Returns: generated content as string
function execute_awk_script_with_input(script_code, input_file,    script_file, env_vars, scripts_dir, has_include, include_file, common_lib_file, preprocessed_script, lib_exists, lib_read_error, cmd, line, generated_content, script_lines_count, script_lines, i, norm_data) {
    # Write AWK script to temp file
    script_file = "/tmp/awk_script_" NR "_" rand() ".awk"
    print script_code > script_file
    close(script_file)
    
    # Build environment variables string
    env_vars = ""
    
    # Pass NORMALIZATION_MACROS_DATA for type normalization templates
    if ("NORMALIZATION_MACROS_DATA" in ENVIRON && ENVIRON["NORMALIZATION_MACROS_DATA"] != "") {
        norm_data = ENVIRON["NORMALIZATION_MACROS_DATA"]
        gsub(/"/, "\\\"", norm_data)
        env_vars = env_vars " NORMALIZATION_MACROS_DATA=\"" norm_data "\""
    }
    
    # Pass file paths for template constructs
    if ("POINTER_TYPES_FILE" in ENVIRON && ENVIRON["POINTER_TYPES_FILE"] != "") {
        env_vars = env_vars " POINTER_TYPES_FILE=\"" ENVIRON["POINTER_TYPES_FILE"] "\""
    }
    if ("NON_POINTER_TYPES_FILE" in ENVIRON && ENVIRON["NON_POINTER_TYPES_FILE"] != "") {
        env_vars = env_vars " NON_POINTER_TYPES_FILE=\"" ENVIRON["NON_POINTER_TYPES_FILE"] "\""
    }
    
    # Check if script uses @include - need to preprocess
    scripts_dir = ENVIRON["SCRIPTS_DIR"]
    if (scripts_dir == "") scripts_dir = "."
    
    # Read script file to check for @include
    has_include = 0
    include_file = ""
    script_lines_count = 0
    delete script_lines
    
    while ((getline line < script_file) > 0) {
        script_lines_count++
        script_lines[script_lines_count] = line
        
        if (!has_include && line ~ /^@include[ \t]+"/) {
            has_include = 1
            if (match(line, /"([^"]+)"/)) {
                include_file = substr(line, RSTART + 1, RLENGTH - 2)
            }
        }
    }
    close(script_file)
    
    if (has_include && include_file != "") {
        # Preprocess: create new script file with included library
        common_lib_file = scripts_dir "/" include_file
        preprocessed_script = "/tmp/awk_preprocessed_" NR "_" rand() ".awk"
        
        # Check if common library file exists and copy it
        lib_exists = 0
        lib_read_error = 0
        while ((getline line < common_lib_file) > 0) {
            lib_exists = 1
            print line > preprocessed_script
        }
        if ((getline < common_lib_file) < 0 && lib_exists == 0) {
            lib_read_error = 1
        }
        close(common_lib_file)
        
        if (lib_read_error || !lib_exists) {
            print "ERROR: Common library file not found: " common_lib_file > "/dev/stderr"
            print "ERROR: Script requires @include \"" include_file "\" but library is missing" > "/dev/stderr"
            print "ERROR: Check SCRIPTS_DIR environment variable (current: " scripts_dir ")" > "/dev/stderr"
            system("rm -f " script_file)
            exit 1
        }
        
        # Add separator comment
        print "" > preprocessed_script
        print "# ============================================================================" > preprocessed_script
        print "# Main script (from template)" > preprocessed_script
        print "# ============================================================================" > preprocessed_script
        print "" > preprocessed_script
        
        # Copy original script lines (skip @include line)
        for (i = 1; i <= script_lines_count; i++) {
            if (!(script_lines[i] ~ /^@include/)) {
                print script_lines[i] > preprocessed_script
            }
        }
        close(preprocessed_script)
        
        # Use preprocessed script
        # Use AWK_CMD from environment, fallback to gawk
        awk_cmd = (ENVIRON["AWK_CMD"] != "") ? ENVIRON["AWK_CMD"] : "gawk"
        if (env_vars != "") {
            if (input_file != "") {
                cmd = "env" env_vars " " awk_cmd " -f " preprocessed_script " " input_file " 2>&1"
            } else {
                cmd = "env" env_vars " " awk_cmd " -f " preprocessed_script " 2>&1"
            }
        } else {
            if (input_file != "") {
                cmd = awk_cmd " -f " preprocessed_script " " input_file " 2>&1"
            } else {
                cmd = awk_cmd " -f " preprocessed_script " 2>&1"
            }
        }
    } else {
        # Regular awk (no @include)
        # Use AWK_CMD from environment, fallback to gawk
        awk_cmd = (ENVIRON["AWK_CMD"] != "") ? ENVIRON["AWK_CMD"] : "gawk"
        if (env_vars != "") {
            if (input_file != "") {
                cmd = "env" env_vars " " awk_cmd " -f " script_file " " input_file " 2>&1"
            } else {
                cmd = "env" env_vars " " awk_cmd " -f " script_file " 2>&1"
            }
        } else {
            if (input_file != "") {
                cmd = awk_cmd " -f " script_file " " input_file " 2>&1"
            } else {
                cmd = awk_cmd " -f " script_file " 2>&1"
            }
        }
    }
    
    # Execute and capture output
    generated_content = ""
    while ((cmd | getline line) > 0) {
        if (generated_content != "") {
            generated_content = generated_content "\n"
        }
        generated_content = generated_content line
    }
    close(cmd)
    
    # Cleanup
    system("rm -f " script_file)
    if (has_include && include_file != "") {
        system("rm -f " preprocessed_script)
    }
    
    return generated_content
}

