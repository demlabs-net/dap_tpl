#!/bin/bash
# DAP Template Processing Library - New Clean Architecture
# Provides functions for processing template files with placeholders and embedded scripts
#
# Usage:
#   source dap_tpl.sh
#   replace_template_placeholders <template_file> <output_file> <var1=value1> <var2=value2> ...

set -e

# Colors for output (if not already defined)
if [ -z "${RED:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
fi

# Print error message
tpl_print_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

# Function to replace placeholders in template file
# Usage: replace_template_placeholders <template_file> <output_file> <var1=value1> <var2=value2> ...
# For multi-line values, use a temporary file: replace_template_placeholders <template> <output> <var1=@file1> <var2=value2>
# 
# Environment variables:
#   SCRIPTS_DIR - directory containing AWK scripts for template processing (defaults to script directory)
#   TEMPLATES_DIR - directory containing template files (defaults to templates/ subdirectory)
replace_template_placeholders() {
    local template_file="$1"
    local output_file="$2"
    # Save original arguments before shifting (needed for placeholder replacement loop)
    local placeholder_args=("$@")
    shift 2
    
    if [ ! -f "$template_file" ]; then
        tpl_print_error "Template file not found: $template_file"
        return 1
    fi
    
    # Set SCRIPTS_DIR if not set
    if [ -z "${SCRIPTS_DIR:-}" ]; then
        # Get directory where this script is located
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        SCRIPTS_DIR="${script_dir}"
    fi
    
    if [ -z "${TEMPLATES_DIR:-}" ]; then
        # Templates are in test-framework/templates (one level up from dap_tpl)
        TEMPLATES_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)/templates"
    fi
    
    export SCRIPTS_DIR
    export TEMPLATES_DIR
    
    # Export all variables passed as arguments (VAR=value) to ENVIRON
    # This allows AWK scripts to access them via ENVIRON array
    # Variables are passed explicitly as function arguments, not hardcoded
    # Multi-line values are preserved by reading from the first = to end of argument
    # File references (@filename) are read and exported as variable content
    # Track exported variables for explicit passing to subprocesses
    local exported_vars=()
    local var_args=("$@")
    for var_arg in "${var_args[@]}"; do
        if [[ "$var_arg" == *"="* ]]; then
            local var_name="${var_arg%%=*}"
            # Extract value after first = (to handle values containing =)
            local var_val="${var_arg#*=}"
            
            # Check if value is a file reference (@filename)
            if [ "${var_val:0:1}" = "@" ]; then
                local val_file="${var_val:1}"
                if [ -f "$val_file" ]; then
                    # Read file content and export as variable
                    # This preserves newlines for {{#for}} constructs
                    # Use declare to ensure variable is created before printf
                    # Note: We use declare here (not local) so variable is accessible in subprocesses
                    declare "$var_name"
                    local file_content=$(cat "$val_file")
                    printf -v "$var_name" '%s' "$file_content"
                    # Export variable so it's available in AWK subprocess ENVIRON
                    export "$var_name"
                    # Track exported variable for explicit passing to subprocesses
                    exported_vars+=("$var_name")
                fi
            else
                # Simple value - export directly
                # Use declare to ensure variable is created before printf
                declare "$var_name"
                printf -v "$var_name" '%s' "$var_val"
                export "$var_name"
                # Track exported variable for explicit passing to subprocesses
                exported_vars+=("$var_name")
            fi
        fi
    done
    
    # Build environment variable assignments for env command
    local env_vars_str=""
    if [ ${#exported_vars[@]} -gt 0 ]; then
        for var_name in "${exported_vars[@]}"; do
            # Get variable value using indirect reference
            local var_value="${!var_name}"
            # Use printf %q to properly quote the value
            local quoted_value=$(printf '%q' "$var_value")
            env_vars_str="$env_vars_str ${var_name}=${quoted_value}"
        done
    fi
    
    # Process template using new engine
    # Export AWKPATH for @include support
    export AWKPATH="${SCRIPTS_DIR}"
    
    # Create temporary file for output
    local temp_output=$(mktemp)
    
    # Execute dap_tpl_engine.awk with environment variables
    if [ ${#exported_vars[@]} -gt 0 ]; then
        (
            cd "${SCRIPTS_DIR}" && \
            eval "env$env_vars_str AWKPATH=\"${SCRIPTS_DIR}\" gawk -f \"dap_tpl_engine.awk\" \"$template_file\" > \"$temp_output\""
        )
    else
        (
            cd "${SCRIPTS_DIR}" && \
            env AWKPATH="${SCRIPTS_DIR}" gawk -f "dap_tpl_engine.awk" "$template_file" > "$temp_output"
        )
    fi
    
    # Check if processing succeeded
    if [ ! -s "$temp_output" ]; then
        tpl_print_error "Template processing produced empty output"
        rm -f "$temp_output"
        return 1
    fi
    
    # Copy output to destination file
    cp "$temp_output" "$output_file"
    rm -f "$temp_output"
}

