#!/bin/sh
# DAP Template Processing Library

set -e

# Detect AWK implementation — strictly mawk only
detect_awk() {
    if command -v mawk >/dev/null 2>&1; then
        echo "mawk"
        return 0
    fi
    echo "ERROR: mawk is required but not found. Install: apt install mawk" >&2
    return 1
}

AWK_CMD=$(detect_awk)
export AWK_CMD

export DAP_AWK_PID="$$"
export DAP_AWK_SYSTIME="$(date +%s)"

# Main function
replace_template_placeholders() {
    local template_file="$1"
    local output_file="${2:-}"
    local var_arg var_name var_val val_file
    local extensions_dir=""
    local _skip_next=0

    [ ! -f "$template_file" ] && echo "ERROR: Template not found: $template_file" >&2 && return 1

    if [ -n "$DAP_TPL_DIR" ]; then
        SCRIPT_DIR="$DAP_TPL_DIR"
    else
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    fi
    export SCRIPTS_DIR="${SCRIPT_DIR}"
    export AWKPATH="${SCRIPT_DIR}"

    local arg_index=0
    for var_arg in "$@"; do
        arg_index=$((arg_index + 1))
        [ "$arg_index" -eq 1 ] && continue
        if [ "$arg_index" -eq 2 ]; then
            case "$var_arg" in *=*) ;; *) continue ;; esac
        fi

        if [ "$_skip_next" = "1" ]; then
            _skip_next=0
            continue
        fi

        case "$var_arg" in
            --extensions-dir)
                _skip_next=1
                # Peek ahead: capture next positional arg as extensions_dir value
                local _peek_idx=0
                for _peek_arg in "$@"; do
                    _peek_idx=$((_peek_idx + 1))
                    [ "$_peek_idx" -le "$arg_index" ] && continue
                    extensions_dir="$_peek_arg"
                    break
                done
                continue
                ;;
            --*)
                _skip_next=1
                continue
                ;;
            *=*)
                var_name="${var_arg%%=*}"
                var_val="${var_arg#*=}"
                # Bash arrays can't be exported to env; unset first to force scalar
                unset "$var_name" 2>/dev/null || true
                case "$var_val" in
                    @*)
                        val_file="${var_val#@}"
                        [ -f "$val_file" ] && export "$var_name"="$(cat "$val_file")"
                        ;;
                    *)
                        export "$var_name"="$var_val"
                        ;;
                esac
                ;;
        esac
    done

    # Engine caching (two levels):
    # 1) In-process: DAP_TPL_ENGINE_PATH env var (same shell, multiple calls)
    # 2) Cross-process: filesystem cache keyed by source dir content hash
    #    build_engine.sh takes ~1.3s; with 6 test targets × 7 calls = 42 builds avoided
    local ENGINE=""
    if [ -n "${DAP_TPL_ENGINE_PATH:-}" ] && [ -f "${DAP_TPL_ENGINE_PATH:-}" ]; then
        ENGINE="$DAP_TPL_ENGINE_PATH"
    else
        # Cross-process cache: deterministic path based on source tree mtime
        local _cache_base="/tmp/dap_tpl_engine_cache"
        local _cache_key
        _cache_key=$(printf '%s:%s' "$SCRIPT_DIR" "$extensions_dir" | cksum | cut -d' ' -f1)
        local _cache_dir="${_cache_base}/${_cache_key}"
        local _cached_engine="${_cache_dir}/dap_tpl_engine.awk"
        local _cache_stamp="${_cache_dir}/.stamp"

        # Check if cached engine is still valid (source AWK files not modified)
        local _need_rebuild=1
        if [ -f "$_cached_engine" ] && [ -f "$_cache_stamp" ]; then
            local _src_newest
            _src_newest=$(find "$SCRIPT_DIR" -name '*.awk' -newer "$_cache_stamp" 2>/dev/null | head -1)
            if [ -z "$_src_newest" ]; then
                # Also check extensions dir if present
                if [ -n "$extensions_dir" ] && [ -d "$extensions_dir" ]; then
                    _src_newest=$(find "$extensions_dir" -name '*.awk' -newer "$_cache_stamp" 2>/dev/null | head -1)
                fi
                [ -z "$_src_newest" ] && _need_rebuild=0
            fi
        fi

        if [ "$_need_rebuild" = "0" ]; then
            ENGINE="$_cached_engine"
        else
            mkdir -p "$_cache_dir"
            export DAP_TPL_TEMP_DIR="$_cache_dir"
            local _engine_stderr _engine_rc=0
            _engine_stderr=$("${SCRIPT_DIR}/utils/build_engine.sh" "$extensions_dir" 2>&1 >/dev/null) || _engine_rc=$?
            if [ "$_engine_rc" -ne 0 ]; then
                echo "ERROR: Engine build failed (exit code $_engine_rc)" >&2
                [ -n "$_engine_stderr" ] && echo "$_engine_stderr" >&2
                return 1
            fi
            ENGINE="${_cache_dir}/dap_tpl_engine.awk"
            [ ! -f "$ENGINE" ] && echo "ERROR: Engine file not found after build: $ENGINE" >&2 && return 1
            touch "$_cache_stamp"
        fi
        export DAP_TPL_ENGINE_PATH="$ENGINE"
        export DAP_TPL_TEMP_DIR="${_cache_dir}"
    fi

    local result=0
    if [ -n "$output_file" ]; then
        DEBUG_ENABLED=0 "$AWK_CMD" -f "$ENGINE" "$template_file" > "$output_file" || result=$?
    else
        DEBUG_ENABLED=0 "$AWK_CMD" -f "$ENGINE" "$template_file" || result=$?
    fi

    return $result
}

# Reset in-process engine cache (cross-process filesystem cache persists).
# Call between test targets if extensions change, or at script exit.
dap_tpl_cleanup() {
    unset DAP_TPL_ENGINE_PATH DAP_TPL_TEMP_DIR
}

# Remove the cross-process filesystem cache entirely.
dap_tpl_purge_cache() {
    rm -rf /tmp/dap_tpl_engine_cache 2>/dev/null || true
    dap_tpl_cleanup
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
