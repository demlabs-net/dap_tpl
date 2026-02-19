#!/bin/sh
# DAP Template Processing Library

set -e

# Detect AWK implementation
detect_awk() {
    if command -v mawk >/dev/null 2>&1; then
        echo "mawk"
    elif command -v awk >/dev/null 2>&1; then
        echo "awk"
    else
        echo "awk"
    fi
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
            --*)
                # Skip flags (like --extensions-dir) and their values
                # Next argument will be the value, skip it too in next iteration
                continue
                ;;
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
    
    # Build engine - use unique temp file per process to support parallel execution
    # Combine PID with a random suffix for uniqueness even with subshells
    ENGINE="/tmp/dap_tpl_engine_$$.awk"
    DAP_TPL_ENGINE_OUTPUT="$ENGINE" "${SCRIPT_DIR}/utils/build_engine.sh" >/dev/null 2>&1
    
    [ ! -f "$ENGINE" ] && echo "ERROR: Engine build failed" >&2 && return 1
    
    # Process template
    export DAP_TPL_ENGINE_PATH="$ENGINE"
    
    local result=0
    if [ -n "$output_file" ]; then
        DEBUG_ENABLED=0 "$AWK_CMD" -f "$ENGINE" "$template_file" > "$output_file" 2>&1 || result=$?
    else
        DEBUG_ENABLED=0 "$AWK_CMD" -f "$ENGINE" "$template_file" 2>&1 || result=$?
    fi
    
    # Cleanup unique engine file
    rm -f "$ENGINE" 2>/dev/null || true
    
    return $result
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
