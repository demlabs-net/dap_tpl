#!/bin/bash
# Build Engine Script
# Собирает dap_tpl engine из модулей конструкций
# Usage: ./build_engine.sh [extensions_dir]

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAP_TPL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# Generate engine file in /tmp with PID for parallel execution support
ENGINE_FILE="/tmp/dap_tpl_compiled_$$.awk"
CONSTRUCTS_DIR="${DAP_TPL_DIR}/constructs"
EXTENSIONS_DIR="${1:-}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Build the engine file (in root of dap_tpl directory)
cat > "${ENGINE_FILE}" <<EOF
# AUTO-GENERATED by build_engine.sh
# Do not edit manually - regenerate with: ./utils/build_engine.sh

# Core includes
@include "core/token_tree.awk"
@include "core/variable_context.awk"
@include "core/macro_store.awk"
@include "core/renderer.awk"
@include "core/construct_registry.awk"

# Helper includes (for plugin development)
@include "core/marker_utils.awk"
@include "core/tokenizer_helpers.awk"
@include "core/metadata_helpers.awk"
@include "core/child_helpers.awk"
@include "core/generic_branch_parser.awk"
@include "core/conditional_evaluator_helpers.awk"

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
@include "core/tokenizer_core.awk"
@include "core/evaluator_core.awk"

# Construct includes (auto-generated list)
EOF

# Add @include for each construct
for construct in "${ALL_CONSTRUCTS[@]}"; do
    if [ -f "${CONSTRUCTS_DIR}/${construct}/tokenizer.awk" ]; then
        echo "@include \"constructs/${construct}/tokenizer.awk\"" >> "${ENGINE_FILE}"
    fi
    if [ -f "${CONSTRUCTS_DIR}/${construct}/branch_parser.awk" ]; then
        echo "@include \"constructs/${construct}/branch_parser.awk\"" >> "${ENGINE_FILE}"
    fi
    if [ -f "${CONSTRUCTS_DIR}/${construct}/content_parser.awk" ]; then
        echo "@include \"constructs/${construct}/content_parser.awk\"" >> "${ENGINE_FILE}"
    fi
    if [ -f "${CONSTRUCTS_DIR}/${construct}/evaluator.awk" ]; then
        echo "@include \"constructs/${construct}/evaluator.awk\"" >> "${ENGINE_FILE}"
    fi
    
    # Handle extensions
    if [ -n "${EXTENSIONS_DIR}" ] && [ -d "${EXTENSIONS_DIR}/${construct}" ]; then
        if [ -f "${EXTENSIONS_DIR}/${construct}/tokenizer.awk" ]; then
            # Use relative path from DAP_TPL_DIR
            rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/${construct}/tokenizer.awk")
            echo "@include \"${rel_path}\"" >> "${ENGINE_FILE}"
        fi
        if [ -f "${EXTENSIONS_DIR}/${construct}/branch_parser.awk" ]; then
            rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/${construct}/branch_parser.awk")
            echo "@include \"${rel_path}\"" >> "${ENGINE_FILE}"
        fi
        if [ -f "${EXTENSIONS_DIR}/${construct}/content_parser.awk" ]; then
            rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/${construct}/content_parser.awk")
            echo "@include \"${rel_path}\"" >> "${ENGINE_FILE}"
        fi
        if [ -f "${EXTENSIONS_DIR}/${construct}/evaluator.awk" ]; then
            rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/${construct}/evaluator.awk")
            echo "@include \"${rel_path}\"" >> "${ENGINE_FILE}"
        fi
    fi
done

# Include extensions variable functions if extensions directory is provided
# This allows extensions to register additional variable functions
if [ -n "${EXTENSIONS_DIR}" ] && [ -f "${EXTENSIONS_DIR}/variable_functions.awk" ]; then
    rel_path=$(realpath --relative-to="${DAP_TPL_DIR}" "${EXTENSIONS_DIR}/variable_functions.awk")
    echo "@include \"${rel_path}\"" >> "${ENGINE_FILE}"
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
# Output path for scripts to capture
echo "ENGINE_PATH=${ENGINE_FILE}"

