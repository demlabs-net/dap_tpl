#!/bin/bash
# Test helpers for AWK engine

# Build engine if needed
ensure_engine() {
    local engine_path="/tmp/dap_tpl_engine.awk"
    
    if [ ! -f "$engine_path" ] || [ "$DAP_TPL_DIR/utils/build_engine.sh" -nt "$engine_path" ]; then
        echo "Building engine..." >&2
        (cd "$DAP_TPL_DIR" && ./utils/build_engine.sh >/dev/null 2>&1)
    fi
    
    echo "$engine_path"
}

# Run AWK test with engine
run_awk_test() {
    local test_file="$1"
    local temp_stdout=$(mktemp)
    local temp_stderr=$(mktemp)
    local exit_code=0
    
    local engine=$(ensure_engine)
    
    (cd "$DAP_TPL_DIR" && DEBUG_ENABLED=0 mawk -f "$test_file" <<< "" > "$temp_stdout" 2>"$temp_stderr") || exit_code=$?
    
    cat "$temp_stdout"
    cat "$temp_stderr" >&2
    rm -f "$temp_stdout" "$temp_stderr"
    
    return $exit_code
}

# Process template with engine
process_template() {
    local template="$1"
    local engine=$(ensure_engine)
    
    echo "$template" | mawk -f "$engine" 2>&1
}
