#!/bin/sh
# DAP Template Processing Library

set -e

# Detect AWK implementation with systime() support
# systime() is required but it's a gawk extension (not in POSIX awk or mawk)
detect_awk() {
    local awk_cmd
    # Try each AWK in order of preference
    for awk_cmd in gawk mawk awk; do
        if command -v "$awk_cmd" >/dev/null 2>&1; then
            # Test if this AWK supports systime()
            if "$awk_cmd" 'BEGIN { print systime() }' >/dev/null 2>&1; then
                echo "$awk_cmd"
                return 0
            fi
        fi
    done
    # Fallback (will likely fail, but CMake check should catch this)
    echo "awk"
}

AWK_CMD=$(detect_awk)

# Main function
replace_template_placeholders() {
    local template_file="$1"
    local output_file="${2:-}"
    local var_arg var_name var_val val_file
    
    [ ! -f "$template_file" ] && echo "ERROR: Template not found: $template_file" >&2 && return 1
    
    # Get script directory
    # Use DAP_TPL_DIR if set (when sourced), otherwise detect from $0
    if [ -n "$DAP_TPL_DIR" ]; then
        SCRIPT_DIR="$DAP_TPL_DIR"
    else
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    fi
    export SCRIPTS_DIR="${SCRIPT_DIR}"
    export AWKPATH="${SCRIPT_DIR}"
    
    # Export variables - skip template_file and output_file arguments
    local arg_index=0
    for var_arg in "$@"; do
        arg_index=$((arg_index + 1))
        
        # Skip first argument (template_file)
        [ "$arg_index" -eq 1 ] && continue
        
        # Skip second argument if it's not a variable assignment (it's output_file)
        if [ "$arg_index" -eq 2 ]; then
            case "$var_arg" in
                *=*) ;;  # It's a variable, process it
                *) continue ;;  # It's output_file, skip it
            esac
        fi
        
        case "$var_arg" in
            *=*)
                var_name="${var_arg%%=*}"
                var_val="${var_arg#*=}"
                
                case "$var_val" in
                    @*)
                        # Read from file
                        val_file="${var_val#@}"
                        if [ -f "$val_file" ]; then
                            export "$var_name"="$(cat "$val_file")"
                        fi
                        ;;
                    *)
                        export "$var_name"="$var_val"
                        ;;
                esac
                ;;
        esac
    done
    
    # Build engine
    "${SCRIPT_DIR}/utils/build_engine.sh" >/dev/null 2>&1
    ENGINE="/tmp/dap_tpl_engine.awk"
    
    [ ! -f "$ENGINE" ] && echo "ERROR: Engine build failed" >&2 && return 1
    
    # Process template
    export DAP_TPL_ENGINE_PATH="$ENGINE"
    
    if [ -n "$output_file" ]; then
        # Run AWK and keep stderr separate from stdout
        # This prevents AWK errors/warnings from polluting output files
        # Note: We don't check exit code because AWK may return non-zero on warnings
        # but still produce valid output
        DEBUG_ENABLED=0 "$AWK_CMD" -f "$ENGINE" "$template_file" > "$output_file" 2>&2
    else
        DEBUG_ENABLED=0 "$AWK_CMD" -f "$ENGINE" "$template_file" 2>&2
    fi
}

# Call main function if script is executed directly (not sourced)
# In bash: when sourced, $0 != ${BASH_SOURCE[0]}
# In sh: we check if $0 contains dap_tpl.sh
if [ "$#" -gt 0 ] && [ -n "${BASH_SOURCE-}" ]; then
    # Bash detected, check if executed directly
    if [ "${BASH_SOURCE[0]}" = "$0" ]; then
        replace_template_placeholders "$@"
    fi
elif [ "$#" -gt 0 ] && [ -z "${BASH_SOURCE-}" ]; then
    # Plain sh, check if $0 looks like this script
    case "$0" in
        *dap_tpl.sh)
            replace_template_placeholders "$@"
            ;;
    esac
fi
