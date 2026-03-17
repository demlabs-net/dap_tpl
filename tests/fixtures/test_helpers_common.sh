#!/bin/bash
# Common test helpers - for running AWK tests with @include preprocessing

# Detect AWK — strictly mawk only
detect_awk() {
    if command -v mawk >/dev/null 2>&1; then
        echo "mawk"
        return 0
    fi
    echo "ERROR: mawk is required but not found" >&2
    return 1
}

AWK_CMD="${AWK_CMD:-$(detect_awk)}"

# Run AWK test file with full preprocessing (includes, indirect calls, etc)
run_preprocessed_awk_test() {
    local test_file="$1"
    local dap_tpl_dir="${2:-$(cd "$(dirname "$test_file")/../../.." && pwd)}"
    
    # Step 1: Expand @include directives
    local temp1="/tmp/dap_tpl_test_$$_1.awk"
    local awk_path="${AWKPATH:-${dap_tpl_dir}}"
    if ! AWKPATH="${awk_path}" "${dap_tpl_dir}/utils/awk_include_preprocessor.sh" "$test_file" "${dap_tpl_dir}" > "$temp1" 2>/dev/null; then
        echo "ERROR: Failed to preprocess includes in $test_file" >&2
        rm -f "$temp1"
        return 2
    fi
    
    # Step 2: Process multidimensional for loops
    local temp2="/tmp/dap_tpl_test_$$_2.awk"
    if ! "${dap_tpl_dir}/utils/multidim_for_preprocessor.sh" "$temp1" "$temp2" 2>/dev/null; then
        echo "ERROR: Failed to process multidim for loops" >&2
        rm -f "$temp1" "$temp2"
        return 2
    fi
    rm -f "$temp1"
    
    # Step 3: Process indirect function calls (use ALL functions version for tests)
    local temp3="/tmp/dap_tpl_test_$$_3.awk"
    if ! "${dap_tpl_dir}/utils/indirect_call_processor_all.sh" "$temp2" "$temp3" 2>/dev/null; then
        echo "ERROR: Failed to process indirect calls" >&2
        rm -f "$temp2" "$temp3"
        return 2
    fi
    rm -f "$temp2"
    
    # Step 4: Normalize create_token calls
    local temp4="/tmp/dap_tpl_test_$$_4.awk"
    if ! "${dap_tpl_dir}/utils/normalize_create_token.sh" "$temp3" "$temp4" 2>/dev/null; then
        echo "ERROR: Failed to normalize create_token" >&2
        rm -f "$temp3" "$temp4"
        return 2
    fi
    rm -f "$temp3"
    
    # Step 5: Apply POSIX compatibility layer
    local temp5="/tmp/dap_tpl_test_$$_5.awk"
    if ! "${dap_tpl_dir}/utils/posix_compat_preprocessor.sh" "$temp4" "$temp5" 2>/dev/null; then
        echo "ERROR: Failed to apply POSIX compatibility layer" >&2
        rm -f "$temp4" "$temp5"
        return 2
    fi
    rm -f "$temp4"
    
    # Run preprocessed test with detected AWK
    local result
    local exit_code=0
    # Export POSIX compat vars for the test
    export DAP_AWK_PID="$$"
    export DAP_AWK_SYSTIME="$(date +%s)"
    
    if result=$(cd "$dap_tpl_dir" && "$AWK_CMD" -f "$temp5" <<< "" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    rm -f "$temp5"
    echo "$result"
    return $exit_code
}
