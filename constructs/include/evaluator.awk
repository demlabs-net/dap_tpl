# INCLUDE Construct Evaluator
# Evaluates include constructs: {{#include FILE}}

@include "core/token_tree.awk"
@include "core/variable_context.awk"

function evaluate_include(token_id, depth,    file_path, condition, metadata, file_content, line, text_token_id, scripts_dir, temp_output, cmd, processed_content, var_name, templates_dir, full_path, var_value, env_file, file_path_escaped, engine_file_escaped, scripts_dir_escaped, temp_output_escaped) {
    if (depth == "") depth = 0
    
    if (depth > 10) {
        print "ERROR: Maximum include recursion depth exceeded" > "/dev/stderr"
        return 0
    }
    
    condition = get_token_metadata(token_id, "condition")
    if (condition == "") {
        return 0
    }
    
    file_path = condition
    if (condition in ENVIRON) {
        file_path = ENVIRON[condition]
    } else {
        file_path = get_var(condition)
        if (file_path == "") {
            file_path = condition
        }
    }
    
    # Remove quotes if present (e.g., "included.tpl" -> included.tpl)
    gsub(/^["']|["']$/, "", file_path)
    gsub(/^[ \t]+|[ \t]+$/, "", file_path)
    
    if (file_path == "" || file_path == "{{" condition "}}") {
        return 0
    }
    
    # Resolve file path using TEMPLATES_DIR if file is not absolute
    templates_dir = ENVIRON["TEMPLATES_DIR"]
    if (templates_dir != "" && file_path !~ /^\//) {
        # First try: TEMPLATES_DIR/file_path
        full_path = templates_dir "/" file_path
        if ((getline line < full_path) >= 0) {
            close(full_path)
            file_path = full_path
        } else {
            close(full_path)
            # Second try: relative to current working directory
            # This allows includes from subdirectories in templates
            if ((getline line < file_path) >= 0) {
                close(file_path)
                # file_path remains as-is (relative)
            } else {
                close(file_path)
                # File not found in either location
                # Keep file_path as-is and let subsequent code handle the error
            }
        }
    }
    
    if (file_path ~ /\.tpl$/) {
        scripts_dir = ENVIRON["SCRIPTS_DIR"]
        if (scripts_dir == "") scripts_dir = "."
        
        # Use PID and timestamp for unique temp file name to avoid collisions in parallel builds
        temp_output = "/tmp/include_" PROCINFO["pid"] "_" NR "_" depth "_" rand() "_" systime() ".out"
        
        # Write environment variables to temporary file to avoid mawk sprintf buffer overflow (8192 bytes)
        # This is more reliable than passing huge env_vars_str through command line
        env_file = "/tmp/include_env_" PROCINFO["pid"] "_" NR "_" depth "_" rand() "_" systime() ".sh"
        
        export_context_to_environ()
        
        # Write all variables to env file
        for (var_name in ENVIRON) {
            # Only export template-related variables, skip system variables
            if (var_name !~ /^(AWKPATH|SCRIPTS_DIR|TEMPLATES_DIR|DAP_TPL_ENGINE_PATH|NR|NF|FILENAME|FNR|FS|RS|ORS|OFMT|CONVFMT|PATH|HOME|USER|SHELL|TERM|LANG|PWD|OLDPWD|SHLVL|LS_COLORS|DISPLAY|XAUTHORITY|XDG_|DBUS_|GNOME_|GTK_|QT_|LD_|VSCODE_|CURSOR_|SSH_|GPG_|WAYLAND_|SESSION_|DESKTOP_|GDM_|IM_|GIO_|GSETTINGS_|MEMORY_|CHROME_|SYSTEMD_|INVOCATION_|MANAGERPID|APPIMAGE|APPDIR|ARGV0|AWKLIBPATH|PERLLIB|COMPOSER_|OWD|JOURNAL_|ORIGINAL_|NO_COLOR|FORCE_COLOR)/) {
                var_value = ENVIRON[var_name]
                # Escape single quotes for shell: ' becomes '\''
                gsub(/'/, "'\\''", var_value)
                print "export " var_name "='" var_value "'" > env_file
            }
        }
        
        if (scripts_dir != "") {
            scripts_dir_escaped = scripts_dir
            gsub(/'/, "'\\''", scripts_dir_escaped)
            print "export SCRIPTS_DIR='" scripts_dir_escaped "'" > env_file
        }
        if (templates_dir != "") {
            templates_dir_escaped = templates_dir
            gsub(/'/, "'\\''", templates_dir_escaped)
            print "export TEMPLATES_DIR='" templates_dir_escaped "'" > env_file
        }
        
        close(env_file)
        
        # Use compiled engine from environment variable (set by dap_tpl.sh)
        # Fallback to PID-based path for backward compatibility
        if ("DAP_TPL_ENGINE_PATH" in ENVIRON && ENVIRON["DAP_TPL_ENGINE_PATH"] != "") {
            compiled_engine = ENVIRON["DAP_TPL_ENGINE_PATH"]
        } else {
            compiled_engine = "/tmp/dap_tpl_compiled_" PROCINFO["pid"] ".awk"
        }
        
        # Verify engine exists
        if ((getline line < compiled_engine) < 0) {
            close(compiled_engine)
            print "ERROR: Compiled engine not found: " compiled_engine > "/dev/stderr"
            return 0
        }
        close(compiled_engine)
        engine_file = compiled_engine
        
        # Build command using env file to avoid sprintf buffer overflow
        # Source env file, then run mawk with engine
        # Note: No need for long sprintf - just source the env file
        file_path_escaped = file_path
        gsub(/'/, "'\\''", file_path_escaped)
        engine_file_escaped = engine_file
        gsub(/'/, "'\\''", engine_file_escaped)
        scripts_dir_escaped = scripts_dir
        gsub(/'/, "'\\''", scripts_dir_escaped)
        temp_output_escaped = temp_output
        gsub(/'/, "'\\''", temp_output_escaped)
        
        # Short command that sources env file
        cmd = "(. '" env_file "' && AWKPATH='" scripts_dir_escaped "' DAP_TPL_ENGINE_PATH='" engine_file_escaped "' mawk -f '" engine_file_escaped "' '" file_path_escaped "') > '" temp_output_escaped "' 2>&1"
        
        rc = system(cmd)
        
        # Clean up env file immediately
        system("rm -f '" env_file "'")
        
        processed_content = ""
        while ((getline line < temp_output) > 0) {
            if (processed_content != "") {
                processed_content = processed_content "\n"
            }
            processed_content = processed_content line
        }
        close(temp_output)
        
        system("rm -f '" temp_output "'")
        
        delete metadata
        text_token_id = create_token("text", processed_content, metadata)
        
        return text_token_id
    } else {
        file_content = ""
        while ((getline line < file_path) > 0) {
            if (file_content != "") {
                file_content = file_content "\n"
            }
            file_content = file_content line
        }
        close(file_path)
        
        delete metadata
        text_token_id = create_token("text", file_content, metadata)
        
        return text_token_id
    }
}

