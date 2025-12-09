# INCLUDE Construct Evaluator
# Evaluates include constructs: {{#include FILE}}

@include "core/token_tree.awk"
@include "core/variable_context.awk"

function evaluate_include(token_id, depth,    file_path, condition, metadata, file_content, line, text_token_id, scripts_dir, temp_output, cmd, processed_content, var_name, templates_dir, full_path, env_vars_str, var_value) {
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
    
    templates_dir = ENVIRON["TEMPLATES_DIR"]
    if (templates_dir != "" && file_path !~ /^\//) {
        full_path = templates_dir "/" file_path
        if ((getline line < full_path) >= 0) {
            close(full_path)
            file_path = full_path
        }
    }
    
    if (file_path ~ /\.tpl$/) {
        scripts_dir = ENVIRON["SCRIPTS_DIR"]
        if (scripts_dir == "") scripts_dir = "."
        
        # Use PID and timestamp for unique temp file name to avoid collisions in parallel builds
        temp_output = "/tmp/include_" PROCINFO["pid"] "_" NR "_" depth "_" rand() "_" systime() ".out"
        
        env_vars_str = ""
        export_context_to_environ()
        
        for (var_name in ENVIRON) {
            # Only export template-related variables, skip system variables
            # This avoids command line length issues and quote escaping problems
            if (var_name !~ /^(AWKPATH|SCRIPTS_DIR|TEMPLATES_DIR|DAP_TPL_ENGINE_PATH|NR|NF|FILENAME|FNR|FS|RS|ORS|OFMT|CONVFMT|PATH|HOME|USER|SHELL|TERM|LANG|PWD|OLDPWD|SHLVL|LS_COLORS|DISPLAY|XAUTHORITY|XDG_|DBUS_|GNOME_|GTK_|QT_|LD_|VSCODE_|CURSOR_|SSH_|GPG_|WAYLAND_|SESSION_|DESKTOP_|GDM_|IM_|GIO_|GSETTINGS_|MEMORY_|CHROME_|SYSTEMD_|INVOCATION_|MANAGERPID|APPIMAGE|APPDIR|ARGV0|AWKLIBPATH|PERLLIB|COMPOSER_|OWD|JOURNAL_|ORIGINAL_|NO_COLOR|FORCE_COLOR)/) {
                var_value = ENVIRON[var_name]
                # Escape single quotes for shell command
                gsub(/'/, "'\\''", var_value)
                env_vars_str = env_vars_str " " var_name "='" var_value "'"
            }
        }
        
        if (scripts_dir != "") {
            # Escape single quotes in path
            scripts_dir_escaped = scripts_dir
            gsub(/'/, "'\\''", scripts_dir_escaped)
            env_vars_str = env_vars_str " SCRIPTS_DIR='" scripts_dir_escaped "'"
        }
        if (templates_dir != "") {
            # Escape single quotes in path
            templates_dir_escaped = templates_dir
            gsub(/'/, "'\\''", templates_dir_escaped)
            env_vars_str = env_vars_str " TEMPLATES_DIR='" templates_dir_escaped "'"
        }
        
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
        
        # Build command with proper quoting
        # CRITICAL: Pass DAP_TPL_ENGINE_PATH to child process so it can use the same engine
        # Note: env_vars_str already includes leading space
        cmd = sprintf("cd '%s' && AWKPATH='%s' DAP_TPL_ENGINE_PATH='%s'%s gawk -f '%s' '%s' > '%s' 2>&1", scripts_dir, scripts_dir, engine_file, env_vars_str, engine_file, file_path, temp_output)
        
        rc = system(cmd)
        
        processed_content = ""
        while ((getline line < temp_output) > 0) {
            if (processed_content != "") {
                processed_content = processed_content "\n"
            }
            processed_content = processed_content line
        }
        close(temp_output)
        
        system("rm -f \"" temp_output "\"")
        
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

