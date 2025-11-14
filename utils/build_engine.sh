#!/bin/bash
# Build Engine Script
# Собирает dap_tpl engine из модулей конструкций
# Usage: ./build_engine.sh [extensions_dir]

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONSTRUCTS_DIR="${DAP_TPL_DIR}/constructs"
EXTENSIONS_DIR="${1:-}"

# Generate cache key based on extensions directory
# Use stable path for caching instead of PID-based to enable reuse
if [ -n "${EXTENSIONS_DIR}" ]; then
    # Create hash of extensions directory path for cache key
    EXTENSIONS_HASH=$(echo -n "${EXTENSIONS_DIR}" | sha256sum | cut -d' ' -f1 | cut -c1-16)
    ENGINE_FILE="/tmp/dap_tpl_compiled_ext_${EXTENSIONS_HASH}.awk"
else
    ENGINE_FILE="/tmp/dap_tpl_compiled_base.awk"
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if engine cache exists and is up-to-date
NEED_REBUILD=true
if [ -f "${ENGINE_FILE}" ]; then
    ENGINE_TIME=$(stat -c %Y "${ENGINE_FILE}" 2>/dev/null || stat -f %m "${ENGINE_FILE}" 2>/dev/null || echo "0")
    NEWEST_SOURCE_TIME=0
    
    # Check all construct definition files
    for def_file in "${CONSTRUCTS_DIR}"/*/definition.awk; do
        if [ -f "$def_file" ]; then
            FILE_TIME=$(stat -c %Y "$def_file" 2>/dev/null || stat -f %m "$def_file" 2>/dev/null || echo "0")
            if [ "$FILE_TIME" -gt "$NEWEST_SOURCE_TIME" ]; then
                NEWEST_SOURCE_TIME=$FILE_TIME
            fi
        fi
    done
    
    # Check extensions directory if provided
    if [ -n "${EXTENSIONS_DIR}" ] && [ -d "${EXTENSIONS_DIR}" ]; then
        for def_file in "${EXTENSIONS_DIR}"/*/definition.awk; do
            if [ -f "$def_file" ]; then
                FILE_TIME=$(stat -c %Y "$def_file" 2>/dev/null || stat -f %m "$def_file" 2>/dev/null || echo "0")
                if [ "$FILE_TIME" -gt "$NEWEST_SOURCE_TIME" ]; then
                    NEWEST_SOURCE_TIME=$FILE_TIME
                fi
            fi
        done
    fi
    
    # Check core files that are always included
    for core_file in "${DAP_TPL_DIR}/core"/*.awk; do
        if [ -f "$core_file" ]; then
            FILE_TIME=$(stat -c %Y "$core_file" 2>/dev/null || stat -f %m "$core_file" 2>/dev/null || echo "0")
            if [ "$FILE_TIME" -gt "$NEWEST_SOURCE_TIME" ]; then
                NEWEST_SOURCE_TIME=$FILE_TIME
            fi
        fi
    done
    
    # Rebuild only if sources are newer than cached engine
    if [ "$NEWEST_SOURCE_TIME" -le "$ENGINE_TIME" ]; then
        NEED_REBUILD=false
    fi
fi

if [ "$NEED_REBUILD" = false ]; then
    echo "ENGINE_PATH=${ENGINE_FILE}"
    exit 0
fi

echo -e "${GREEN}Building dap_tpl engine...${NC}"

# Find all construct directories
declare -a ALL_CONSTRUCTS=()
declare -a CONSTRUCT_DEFINITIONS=()

# Find constructs in main constructs directory
if [ -d "${CONSTRUCTS_DIR}" ]; then
    for construct_dir in "${CONSTRUCTS_DIR}"/*; do
        if [ -d "${construct_dir}" ] && [ -f "${construct_dir}/definition.awk" ]; then
            construct_name=$(basename "${construct_dir}")
            ALL_CONSTRUCTS+=("${construct_name}")
            CONSTRUCT_DEFINITIONS+=("${construct_dir}/definition.awk")
            echo "  Found construct: ${construct_name}"
        fi
    done
fi

# Find constructs in extensions directory if provided
if [ -n "${EXTENSIONS_DIR}" ] && [ -d "${EXTENSIONS_DIR}" ]; then
    echo -e "${YELLOW}  Loading extensions from: ${EXTENSIONS_DIR}${NC}"
    for construct_dir in "${EXTENSIONS_DIR}"/*; do
        if [ -d "${construct_dir}" ] && [ -f "${construct_dir}/definition.awk" ]; then
            construct_name=$(basename "${construct_dir}")
            ALL_CONSTRUCTS+=("${construct_name}")
            CONSTRUCT_DEFINITIONS+=("${construct_dir}/definition.awk")
            echo "  Found extension: ${construct_name}"
        fi
    done
fi

if [ ${#ALL_CONSTRUCTS[@]} -eq 0 ]; then
    echo "Error: No constructs found!"
    exit 1
fi

echo "  Total constructs: ${#ALL_CONSTRUCTS[@]}"

# Generate tokenizer dispatch function
generate_tokenizer_dispatch() {
    echo "# Override stub with actual dispatch implementation"
    echo "function dispatch_tokenizer(func_name, marker_text, pos, start_line, construct_type) {"
    
    for construct in "${ALL_CONSTRUCTS[@]}"; do
        # Extract function name from definition (assume format: register_opening_pattern("name", "pattern", "function_name"))
        func_name=$(grep -h "register_opening_pattern" "${CONSTRUCTS_DIR}/${construct}/definition.awk" "${EXTENSIONS_DIR}/${construct}/definition.awk" 2>/dev/null | \
                    sed -n 's/.*register_opening_pattern.*"\([^"]*\)".*"\([^"]*\)".*/\2/p' | head -1)
        
        if [ -n "${func_name}" ]; then
            echo "    if (func_name == \"${func_name}\") {"
            echo "        return ${func_name}(marker_text, pos, start_line)"
            echo "    }"
        fi
    done
    
    echo "    return 0"
    echo "}"
}

# Generate evaluator dispatch function
generate_evaluator_dispatch() {
    echo "# Override stub with actual dispatch implementation"
    echo "function dispatch_evaluator(func_name, token_id, depth) {"
    
    for construct in "${ALL_CONSTRUCTS[@]}"; do
        # Extract function name from definition
        func_name=$(grep -h "register_evaluator" "${CONSTRUCTS_DIR}/${construct}/definition.awk" "${EXTENSIONS_DIR}/${construct}/definition.awk" 2>/dev/null | \
                    sed -n 's/.*register_evaluator.*"\([^"]*\)".*"\([^"]*\)".*/\2/p' | head -1)
        
        if [ -n "${func_name}" ]; then
            echo "    if (func_name == \"${func_name}\") {"
            # Special handling for include (needs depth parameter)
            if [ "${construct}" = "include" ]; then
                echo "        return ${func_name}(token_id, depth)"
            else
                echo "        return ${func_name}(token_id)"
            fi
            echo "    }"
        fi
    done
    
    echo "    return 0"
    echo "}"
}

# Generate branch parser dispatch function
generate_branch_parser_dispatch() {
    echo "# Dispatch function for branch parsers"
    echo "function dispatch_branch_parser(construct_type, content, token_id, start_line) {"
    echo "    if (construct_type == \"set\") {"
    echo "        printf \"DEBUG dispatch_branch_parser: START for set, token_id=%d content_length=%d content=[%s]\\n\", token_id, length(content), substr(content, 1, 200) > \"/dev/stderr\""
    echo "    }"
    
    for construct in "${ALL_CONSTRUCTS[@]}"; do
        # Extract function name from definition
        func_name=$(grep -h "register_branch_parser" "${CONSTRUCTS_DIR}/${construct}/definition.awk" "${EXTENSIONS_DIR}/${construct}/definition.awk" 2>/dev/null | \
                    sed -n 's/.*register_branch_parser.*"\([^"]*\)".*"\([^"]*\)".*/\2/p' | head -1)
        
        if [ -n "${func_name}" ]; then
            echo "    if (construct_type == \"${construct}\") {"
            echo "        return ${func_name}(content, token_id, start_line)"
            echo "    }"
        fi
    done
    
    echo "    return 0"
    echo "}"
}

# Generate content parser dispatch function
generate_content_parser_dispatch() {
    echo "# Dispatch function for content parsers"
    echo "function dispatch_content_parser(construct_type, content, start_pos, token_id) {"
    
    for construct in "${ALL_CONSTRUCTS[@]}"; do
        # Extract function name from definition
        func_name=$(grep -h "register_content_parser" "${CONSTRUCTS_DIR}/${construct}/definition.awk" "${EXTENSIONS_DIR}/${construct}/definition.awk" 2>/dev/null | \
                    sed -n 's/.*register_content_parser.*"\([^"]*\)".*"\([^"]*\)".*/\2/p' | head -1)
        
        if [ -n "${func_name}" ]; then
            echo "    if (construct_type == \"${construct}\") {"
            echo "        return ${func_name}(content, start_pos, token_id)"
            echo "    }"
        fi
    done
    
    echo "    return start_pos"
    echo "}"
}

# Helper function to extract debug file name from include path
# Converts paths like:
#   "core/conditional_evaluator_helpers.awk" -> "conditional_evaluator_helpers"
#   "conditions/comparison/evaluator.awk" -> "comparison_evaluator"
#   "constructs/if/evaluator.awk" -> "if_evaluator"
extract_debug_name() {
    local include_path="$1"
    # Remove .awk extension
    local path_no_ext="${include_path%.awk}"
    
    # Extract directory parts and filename
    # For paths like "conditions/comparison/evaluator", use "comparison_evaluator"
    # For paths like "constructs/if/evaluator", use "if_evaluator"
    # For simple paths like "core/token_tree", use "token_tree"
    
    local dirname_part=$(dirname "${path_no_ext}")
    local basename_part=$(basename "${path_no_ext}")
    
    # If path has multiple levels (e.g., conditions/comparison/evaluator)
    # Use parent directory + basename (e.g., comparison_evaluator)
    if [[ "${dirname_part}" != "." && "${dirname_part}" != "core" ]]; then
        local parent_dir=$(basename "${dirname_part}")
        # Special handling for conditions/ and constructs/ directories
        if [[ "${path_no_ext}" =~ ^conditions/ ]]; then
            # For conditions/comparison/evaluator -> comparison_evaluator
            echo "${parent_dir}_${basename_part}"
        elif [[ "${path_no_ext}" =~ ^constructs/ ]]; then
            # For constructs/if/evaluator -> if_evaluator
            echo "${parent_dir}_${basename_part}"
        else
            # For other nested paths, use parent_dir_basename
            echo "${parent_dir}_${basename_part}"
        fi
    else
        # Simple path, just use basename
        echo "${basename_part}"
    fi
}

# Helper function to add DEBUG_FILE_NAME before @include
add_debug_name_before_include() {
    local include_path="$1"
    local debug_name=$(extract_debug_name "${include_path}")
    echo "BEGIN { DEBUG_FILE_NAME = \"${debug_name}\" }"
    echo "@include \"${include_path}\""
}

# Build the engine file (in root of dap_tpl directory)
cat > "${ENGINE_FILE}" <<EOF
# AUTO-GENERATED by build_engine.sh
# Do not edit manually - regenerate with: ./utils/build_engine.sh

# Core includes
EOF

# Add core includes with DEBUG_FILE_NAME
add_debug_name_before_include "core/token_tree.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "core/variable_context.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "core/macro_store.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "core/renderer.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "core/construct_registry.awk" >> "${ENGINE_FILE}"

cat >> "${ENGINE_FILE}" <<EOF

# Helper includes (for plugin development)
EOF

add_debug_name_before_include "core/marker_utils.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "core/tokenizer_helpers.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "core/metadata_helpers.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "core/child_helpers.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "core/generic_branch_parser.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "core/conditional_evaluator_helpers.awk" >> "${ENGINE_FILE}"

cat >> "${ENGINE_FILE}" <<EOF

# SH Section Extensions (core registry - extensions can register here)
EOF

add_debug_name_before_include "core/sh_section_extensions.awk" >> "${ENGINE_FILE}"

cat >> "${ENGINE_FILE}" <<EOF

# Dispatch functions must be defined before tokenizer_core and evaluator_core
# (they are used by those modules)
EOF

# Generate dispatch functions BEFORE including core modules that use them
generate_tokenizer_dispatch >> "${ENGINE_FILE}"
echo "" >> "${ENGINE_FILE}"
generate_evaluator_dispatch >> "${ENGINE_FILE}"
echo "" >> "${ENGINE_FILE}"
generate_branch_parser_dispatch >> "${ENGINE_FILE}"
echo "" >> "${ENGINE_FILE}"
generate_content_parser_dispatch >> "${ENGINE_FILE}"

cat >> "${ENGINE_FILE}" <<EOF

# Now include core modules that use dispatch functions
EOF

add_debug_name_before_include "core/tokenizer_core.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "core/evaluator_core.awk" >> "${ENGINE_FILE}"

cat >> "${ENGINE_FILE}" <<EOF

# Condition system (includes condition_parser which includes condition_loader)
EOF

add_debug_name_before_include "core/condition_parser.awk" >> "${ENGINE_FILE}"

# Process condition_loader.awk: replace its @include directives with DEBUG_FILE_NAME versions
# This ensures each condition module gets its own DEBUG_FILE_NAME
cat >> "${ENGINE_FILE}" <<EOF

# Condition loader modules (with DEBUG_FILE_NAME for each)
EOF

# Add DEBUG_FILE_NAME before each condition module include (replacing condition_loader.awk's @include)
add_debug_name_before_include "conditions/logical/and/parser.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/logical/and/evaluator.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/logical/or/parser.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/logical/or/evaluator.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/logical/not/parser.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/logical/not/evaluator.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/comparison/parser.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/comparison/evaluator.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/special/contains/parser.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/special/contains/evaluator.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/special/in/parser.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/special/in/evaluator.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/special/matches/parser.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/special/matches/evaluator.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/simple/parser.awk" >> "${ENGINE_FILE}"
add_debug_name_before_include "conditions/simple/evaluator.awk" >> "${ENGINE_FILE}"

cat >> "${ENGINE_FILE}" <<EOF

# Construct includes (auto-generated list)
EOF

# Add @include for each construct
for construct in "${ALL_CONSTRUCTS[@]}"; do
    if [ -f "${CONSTRUCTS_DIR}/${construct}/definition.awk" ]; then
        add_debug_name_before_include "constructs/${construct}/definition.awk" >> "${ENGINE_FILE}"
    fi
    if [ -f "${CONSTRUCTS_DIR}/${construct}/tokenizer.awk" ]; then
        add_debug_name_before_include "constructs/${construct}/tokenizer.awk" >> "${ENGINE_FILE}"
    fi
    if [ -f "${CONSTRUCTS_DIR}/${construct}/branch_parser.awk" ]; then
        add_debug_name_before_include "constructs/${construct}/branch_parser.awk" >> "${ENGINE_FILE}"
    fi
    if [ -f "${CONSTRUCTS_DIR}/${construct}/content_parser.awk" ]; then
        add_debug_name_before_include "constructs/${construct}/content_parser.awk" >> "${ENGINE_FILE}"
    fi
    if [ -f "${CONSTRUCTS_DIR}/${construct}/evaluator.awk" ]; then
        add_debug_name_before_include "constructs/${construct}/evaluator.awk" >> "${ENGINE_FILE}"
    fi
    if [ -f "${CONSTRUCTS_DIR}/${construct}/render.awk" ]; then
        add_debug_name_before_include "constructs/${construct}/render.awk" >> "${ENGINE_FILE}"
    fi
    if [ -f "${CONSTRUCTS_DIR}/${construct}/process.awk" ]; then
        add_debug_name_before_include "constructs/${construct}/process.awk" >> "${ENGINE_FILE}"
    fi
    if [ -f "${CONSTRUCTS_DIR}/${construct}/helpers.awk" ]; then
        add_debug_name_before_include "constructs/${construct}/helpers.awk" >> "${ENGINE_FILE}"
    fi
    
    # Handle extensions
    if [ -n "${EXTENSIONS_DIR}" ] && [ -d "${EXTENSIONS_DIR}/${construct}" ]; then
        if [ -f "${EXTENSIONS_DIR}/${construct}/tokenizer.awk" ]; then
            # Use relative path from DAP_TPL_DIR
            rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/${construct}/tokenizer.awk")
            add_debug_name_before_include "${rel_path}" >> "${ENGINE_FILE}"
        fi
        if [ -f "${EXTENSIONS_DIR}/${construct}/branch_parser.awk" ]; then
            rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/${construct}/branch_parser.awk")
            add_debug_name_before_include "${rel_path}" >> "${ENGINE_FILE}"
        fi
        if [ -f "${EXTENSIONS_DIR}/${construct}/content_parser.awk" ]; then
            rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/${construct}/content_parser.awk")
            add_debug_name_before_include "${rel_path}" >> "${ENGINE_FILE}"
        fi
        if [ -f "${EXTENSIONS_DIR}/${construct}/evaluator.awk" ]; then
            rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/${construct}/evaluator.awk")
            add_debug_name_before_include "${rel_path}" >> "${ENGINE_FILE}"
        fi
        if [ -f "${EXTENSIONS_DIR}/${construct}/render.awk" ]; then
            rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/${construct}/render.awk")
            add_debug_name_before_include "${rel_path}" >> "${ENGINE_FILE}"
        fi
        if [ -f "${EXTENSIONS_DIR}/${construct}/process.awk" ]; then
            rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/${construct}/process.awk")
            add_debug_name_before_include "${rel_path}" >> "${ENGINE_FILE}"
        fi
    fi
done

# Include extensions variable functions if extensions directory is provided
# This allows extensions to register additional variable functions
if [ -n "${EXTENSIONS_DIR}" ] && [ -f "${EXTENSIONS_DIR}/variable_functions.awk" ]; then
    rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/variable_functions.awk")
    add_debug_name_before_include "${rel_path}" >> "${ENGINE_FILE}"
fi

# Include extensions sh_section extensions if extensions directory is provided
# This allows extensions to register SH section environment variables and filters
# Try multiple possible paths for sh_section_extensions.awk
if [ -n "${EXTENSIONS_DIR}" ]; then
    # Try ../awk/sh_section_extensions.awk relative to extensions dir
    if [ -f "${EXTENSIONS_DIR}/../awk/sh_section_extensions.awk" ]; then
        rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/../awk/sh_section_extensions.awk")
        add_debug_name_before_include "${rel_path}" >> "${ENGINE_FILE}"
    # Try direct path from DAP_TPL_DIR
    elif [ -f "${DAP_TPL_DIR}/../mocks/lib/awk/sh_section_extensions.awk" ]; then
        rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${DAP_TPL_DIR}/../mocks/lib/awk/sh_section_extensions.awk")
        add_debug_name_before_include "${rel_path}" >> "${ENGINE_FILE}"
    fi
fi

# Add registry initialization
cat >> "${ENGINE_FILE}" <<EOF

# Registry initialization (from definitions)
BEGIN {
EOF

# Include all definition files
for def_file in "${CONSTRUCT_DEFINITIONS[@]}"; do
    echo "    # Loading: $(basename $(dirname "${def_file}"))" >> "${ENGINE_FILE}"
    # Extract BEGIN block content from definition file (without BEGIN { and })
    sed -n '/^BEGIN {/,/^}$/p' "${def_file}" | sed '/^BEGIN {/d; /^}$/d; s/^/    /' >> "${ENGINE_FILE}" || true
done

cat >> "${ENGINE_FILE}" <<EOF
}

# Main processing pipeline
BEGIN {
    # Process template file
    if (ARGC >= 2) {
        template_file = ARGV[1]
        
        # Tokenize
        root_token_id = tokenize_file(template_file)
        
        if (root_token_id == 0) {
            print "ERROR: Failed to tokenize template" > "/dev/stderr"
            exit 1
        }
        
        # Evaluate
        evaluated_token_id = evaluate_tree(root_token_id)
        
        if (evaluated_token_id == 0) {
            print "ERROR: Failed to evaluate template" > "/dev/stderr"
            exit 1
        }
        
        # Render
        output_text = render_tree(evaluated_token_id)
        
        # Output result
        print output_text
    } else {
        # Read from stdin
        template_text = ""
        while ((getline line) > 0) {
            if (template_text != "") {
                template_text = template_text "\n"
            }
            template_text = template_text line
        }
        
        if (template_text == "") {
            print "ERROR: No template input provided" > "/dev/stderr"
            exit 1
        }
        
        # Tokenize
        root_token_id = tokenize(template_text)
        
        if (root_token_id == 0) {
            print "ERROR: Failed to tokenize template" > "/dev/stderr"
            exit 1
        }
        
        # Evaluate
        evaluated_token_id = evaluate_tree(root_token_id)
        
        if (evaluated_token_id == 0) {
            print "ERROR: Failed to evaluate template" > "/dev/stderr"
            exit 1
        }
        
        # Render
        output_text = render_tree(evaluated_token_id)
        
        # Output result
        print output_text
    }
}
EOF

echo -e "${GREEN}✓ Engine built successfully: ${ENGINE_FILE}${NC}"
echo "  Constructs included: ${#ALL_CONSTRUCTS[@]}"
echo "  Output: ${ENGINE_FILE}"
echo "  Cached for reuse"
# Output path for scripts to capture
echo "ENGINE_PATH=${ENGINE_FILE}"

