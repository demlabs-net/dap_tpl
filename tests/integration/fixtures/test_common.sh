#!/bin/bash
# Common test fixtures and helper functions for integration tests

AWK_CMD="${AWK_CMD:-awk}"

# Export POSIX compatibility variables
export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Initialize test environment
# Sets up DAP_TPL_DIR, TEMPLATES_DIR, AWKPATH, and builds engine
init_test_env() {
    local test_dir="$1"
    TEST_DIR="$test_dir"
    # Find dap_tpl directory by looking for utils/build_engine.sh
    # Start from test_dir and go up until we find it
    local search_dir="$test_dir"
    DAP_TPL_DIR=""
    while [ -n "$search_dir" ] && [ "$search_dir" != "/" ]; do
        if [ -f "${search_dir}/utils/build_engine.sh" ]; then
            DAP_TPL_DIR="$search_dir"
            break
        fi
        search_dir="$(dirname "$search_dir")"
    done
    if [ -z "$DAP_TPL_DIR" ]; then
        echo "ERROR: Could not find dap_tpl directory (looking for utils/build_engine.sh)"
        exit 1
    fi
    TEMPLATES_DIR="${TEST_DIR}/fixtures"
    FIXTURES_DIR="${TEST_DIR}/fixtures"
    
    export SCRIPTS_DIR="${DAP_TPL_DIR}"
    export TEMPLATES_DIR
    export AWKPATH="${DAP_TPL_DIR}"
    
    # Build engine once at start
    ENGINE_OUTPUT=$("${DAP_TPL_DIR}/utils/build_engine.sh" 2>&1)
    COMPILED_ENGINE=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
    if [ -z "$COMPILED_ENGINE" ] || [ ! -f "$COMPILED_ENGINE" ]; then
        echo "ERROR: Failed to build engine or find engine file"
        echo "$ENGINE_OUTPUT"
        exit 1
    fi
    export DAP_TPL_ENGINE_PATH="$COMPILED_ENGINE"
}

# Run template and capture stdout and stderr
# Parameters:
#   template_file - path to template file
#   temp_stdout_var - variable name to store stdout temp file path (output)
#   temp_stderr_var - variable name to store stderr temp file path (output)
#   output_var - variable name to store stdout output (output)
#   stderr_var - variable name to store stderr output (output)
# Returns: exit code
run_template() {
    local template_file="$1"
    local temp_stdout_var="$2"
    local temp_stderr_var="$3"
    local output_var="$4"
    local stderr_var="$5"
    
    local temp_stdout="/tmp/test_stdout_$$_${RANDOM}.txt"
    local temp_stderr="/tmp/test_stderr_$$_${RANDOM}.txt"
    
    # Set temp file paths using eval
    eval "$temp_stdout_var=\"$temp_stdout\""
    eval "$temp_stderr_var=\"$temp_stderr\""
    
    local exit_code=0
    (cd "$DAP_TPL_DIR" && DEBUG_ENABLED=0 "$AWK_CMD" -f "$COMPILED_ENGINE" "$template_file" > "$temp_stdout" 2>"$temp_stderr") || exit_code=$?
    
    local output=""
    local stderr_output=""
    if [ -f "$temp_stdout" ]; then
        output=$(cat "$temp_stdout")
    fi
    if [ -f "$temp_stderr" ]; then
        stderr_output=$(cat "$temp_stderr")
    fi
    
    # Set output variables using eval (properly escaped)
    eval "$output_var=\$(printf '%s' \"\$output\")"
    eval "$stderr_var=\$(printf '%s' \"\$stderr_output\")"
    
    return $exit_code
}

# Check stderr is empty (no errors)
# Parameters:
#   stderr_output - stderr content to check
#   error_message_prefix - prefix for error message
# Returns: 0 if empty, 1 if not empty
check_stderr_empty() {
    local stderr_output="$1"
    local error_prefix="${2:-FAIL}"
    
    if [ -n "$stderr_output" ]; then
        echo "$error_prefix: Unexpected output in stderr: $stderr_output"
        return 1
    fi
    return 0
}

# Normalize output for comparison
# Parameters:
#   output - output to normalize
# Returns: normalized output
normalize_output() {
    local output="$1"
    printf '%s' "$output" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Compare outputs
# Parameters:
#   actual - actual output
#   expected - expected output
#   test_name - name of the test (for error messages)
# Returns: 0 if match, 1 if mismatch
compare_outputs() {
    local actual="$1"
    local expected="$2"
    local test_name="${3:-Test}"
    
    local actual_norm=$(normalize_output "$actual")
    local expected_norm=$(normalize_output "$expected")
    
    if [ "$actual_norm" != "$expected_norm" ]; then
        echo "FAIL: Output mismatch ($test_name)"
        echo "Expected:"
        echo "$expected" | cat -A
        echo "Got:"
        echo "$actual" | cat -A
        return 1
    fi
    return 0
}

# Cleanup temp files
# Parameters:
#   temp_stdout - path to stdout temp file
#   temp_stderr - path to stderr temp file
cleanup_temp_files() {
    local temp_stdout="$1"
    local temp_stderr="$2"
    rm -f "$temp_stdout" "$temp_stderr"
}

