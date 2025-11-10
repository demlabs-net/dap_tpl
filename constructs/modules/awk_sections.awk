# Module for processing AWK sections in template content
# Provides functions process_awk_sections_in_content() and execute_awk_section()

# Function to process AWK sections in content
function process_awk_sections_in_content(content_text,    lines, n_lines, i, in_awk, awk_code, output_before_awk, line, before_close) {
    # Split content into lines for easier processing
    n_lines = split(content_text, lines, "\n")
    in_awk = 0
    awk_code = ""
    output_before_awk = ""
    
    for (i = 1; i <= n_lines; i++) {
        line = lines[i]
        
        # Check for start of AWK section
        if (line ~ /{{AWK:/) {
            # Output accumulated content before AWK
            if (output_before_awk != "") {
                print output_before_awk
                output_before_awk = ""
            }
            
            in_awk = 1
            # Extract code after {{AWK:
            if (match(line, /{{AWK:(.*)/)) {
                awk_code = substr(line, RSTART + 6)
            } else {
                awk_code = ""
            }
            
            # Check if AWK section ends on same line
            if (line ~ /}}$/) {
                # Remove }} from end
                sub(/}}$/, "", awk_code)
                # Execute AWK code
                execute_awk_section(awk_code)
                awk_code = ""
                in_awk = 0
            }
            continue
        }
        
        # Check for end of AWK section
        if (in_awk) {
            # Check if line contains closing }}
            if (line ~ /^}}$/) {
                # Line is exactly }}
                # Execute AWK code
                execute_awk_section(awk_code)
                awk_code = ""
                in_awk = 0
                # Don't output this line - it's just the closing marker
                continue
            } else if (line ~ /}}$/) {
                # Line ends with }}
                # Extract part before }}
                if (match(line, /^(.*)}}$/)) {
                    before_close = substr(line, RSTART, RLENGTH - 2)
                    if (before_close != "") {
                        awk_code = awk_code "\n" before_close
                    }
                }
                # Execute AWK code
                execute_awk_section(awk_code)
                awk_code = ""
                in_awk = 0
                # Don't output this line - it's just the closing marker
                continue
            } else {
                # Accumulate AWK code
                if (awk_code != "") {
                    awk_code = awk_code "\n" line
                } else {
                    awk_code = line
                }
            }
            continue
        }
        
        # Regular content line
        # Skip template construct markers ({{/if}}, {{/for}}, etc.) - they're handled by replace_template_constructs.awk
        if (line ~ /^{{(\/if|\/for|\/set)}}/) {
            # Skip template construct closing markers
            continue
        }
        if (output_before_awk != "") {
            output_before_awk = output_before_awk "\n" line
        } else {
            output_before_awk = line
        }
    }
    
    # Output remaining content
    if (output_before_awk != "") {
        print output_before_awk
    }
}

# Function to execute AWK section
function execute_awk_section(awk_code,    script_file, scripts_dir, has_include, include_file, common_lib_file, preprocessed_script, lib_exists, lib_read_error, cmd, line, n_lines, code_lines, i, script_lines_count, script_lines) {
    # Execute AWK code with proper environment variable handling
    script_file = "/tmp/template_construct_awk_" NR "_" rand() ".awk"
    # Write AWK code line by line - split by newlines but preserve literal "\n" in strings
    n_lines = split(awk_code, code_lines, "\n")
    for (i = 1; i <= n_lines; i++) {
        if (code_lines[i] != "") {
            printf "%s\n", code_lines[i] > script_file
        } else {
            print "" > script_file
        }
    }
    close(script_file)
    
    # Check if script uses @include - need to preprocess
    scripts_dir = ENVIRON["SCRIPTS_DIR"]
    if (scripts_dir == "") scripts_dir = "."
    
    has_include = 0
    include_file = ""
    script_lines_count = 0
    delete script_lines
    
    # Read script file line by line
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
        preprocessed_script = "/tmp/awk_preprocessed_construct_" NR "_" rand() ".awk"
        
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
            exit 1
        }
        
        # Add separator comment
        print "" > preprocessed_script
        print "# ============================================================================" > preprocessed_script
        print "# Main script (from template construct)" > preprocessed_script
        print "# ============================================================================" > preprocessed_script
        print "" > preprocessed_script
        
        # Copy original script lines (skip @include line)
        for (i = 1; i <= script_lines_count; i++) {
            if (!(script_lines[i] ~ /^@include/)) {
                printf "%s\n", script_lines[i] > preprocessed_script
            }
        }
        close(preprocessed_script)
        
        # Use preprocessed script
        gsub(/"/, "\\\"", preprocessed_script)
        cmd = "gawk -f \"" preprocessed_script "\" 2>&1"
        
        while ((cmd | getline line) > 0) {
            print line
        }
        close(cmd)
        
        system("rm -f " preprocessed_script)
    } else {
        # Regular awk (no @include)
        gsub(/"/, "\\\"", script_file)
        cmd = "gawk -f \"" script_file "\" 2>&1"
        
        while ((cmd | getline line) > 0) {
            print line
        }
        close(cmd)
    }
    
    system("rm -f " script_file)
}

