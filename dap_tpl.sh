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
# Usage: replace_template_placeholders <template_file> <output_file> [--extensions-dir <path>] <var1=value1> <var2=value2> ...
# For multi-line values, use a temporary file: replace_template_placeholders <template> <output> <var1=@file1> <var2=value2>
# 
# Options:
#   --extensions-dir <path> - optional path to extensions directory (e.g., ../mocking)
# 
# Environment variables:
#   SCRIPTS_DIR - directory containing AWK scripts for template processing (defaults to script directory)
#   TEMPLATES_DIR - directory containing template files (defaults to templates/ subdirectory)
replace_template_placeholders() {
    local template_file="$1"
    local output_file="$2"
    shift 2
    
    # Parse optional --extensions-dir parameter
    local extensions_dir=""
    local var_args=()
    while [ $# -gt 0 ]; do
        if [ "$1" = "--extensions-dir" ] && [ $# -gt 1 ]; then
            extensions_dir="$2"
            shift 2
        else
            var_args+=("$1")
            shift
        fi
    done
    set -- "${var_args[@]}"
    
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
    for var_arg in "$@"; do
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
    
    # Process template using engine
    # Export AWKPATH for @include support
    # AWKPATH should point to directory containing dap_tpl scripts (SCRIPTS_DIR)
    # This allows @include "core/..." directives to work
    export AWKPATH="${SCRIPTS_DIR}"
    
    # Build compiled engine and capture path from build_engine.sh output
    # Include extensions directory if provided
    local compiled_engine=""
    
    # Build engine - fail fast if build script doesn't exist
    if [ ! -f "${SCRIPTS_DIR}/utils/build_engine.sh" ]; then
        tpl_print_error "Build script not found: ${SCRIPTS_DIR}/utils/build_engine.sh"
        return 1
    fi
    
    # Build engine with optional extensions directory and capture ENGINE_PATH
    local engine_output
    if [ -n "${extensions_dir}" ]; then
        # Resolve absolute path if relative
        if [ ! "${extensions_dir:0:1}" = "/" ]; then
            extensions_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${extensions_dir}"
        fi
        engine_output=$("${SCRIPTS_DIR}/utils/build_engine.sh" "${extensions_dir}" 2>&1) || {
            tpl_print_error "Failed to build engine"
            echo "$engine_output" >&2
            return 1
        }
    else
        engine_output=$("${SCRIPTS_DIR}/utils/build_engine.sh" 2>&1) || {
            tpl_print_error "Failed to build engine"
            echo "$engine_output" >&2
            return 1
        }
    fi
    
    # Extract ENGINE_PATH from output
    compiled_engine=$(echo "$engine_output" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
    if [ -z "$compiled_engine" ] || [ ! -f "$compiled_engine" ]; then
        tpl_print_error "Engine file was not created or path not found"
        echo "$engine_output" >&2
        return 1
    fi
    
    # Create temporary file for output
    local temp_output=$(mktemp)
    
    # Execute compiled engine with environment variables
    # Change to SCRIPTS_DIR so relative paths in @include work correctly
    # Pass DAP_TPL_ENGINE_PATH so include evaluator can use the same engine
    if [ ${#exported_vars[@]} -gt 0 ]; then
        (
            cd "${SCRIPTS_DIR}" && \
            eval "env$env_vars_str DAP_TPL_ENGINE_PATH=\"${compiled_engine}\" AWKPATH=\"${SCRIPTS_DIR}\" gawk -f \"${compiled_engine}\" \"$template_file\" > \"$temp_output\""
        )
    else
        (
            cd "${SCRIPTS_DIR}" && \
            env DAP_TPL_ENGINE_PATH="${compiled_engine}" AWKPATH="${SCRIPTS_DIR}" gawk -f "${compiled_engine}" "$template_file" > "$temp_output"
        )
    fi
    
    # Cleanup compiled engine file after use (optional - can be kept for caching)
    # rm -f "${compiled_engine}"
    
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

