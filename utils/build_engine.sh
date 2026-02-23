#!/bin/sh
# AWK Build Engine Script
# Creates engine file with @include directives, then expands them

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAP_TPL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PREPROCESSOR="${SCRIPT_DIR}/awk_include_preprocessor.sh"
INDIRECT_PROCESSOR="${SCRIPT_DIR}/indirect_call_processor.sh"
MULTIDIM_FOR_PROCESSOR="${SCRIPT_DIR}/multidim_for_preprocessor.sh"
NORMALIZE_CREATE_TOKEN="${SCRIPT_DIR}/normalize_create_token.sh"
POSIX_COMPAT_PROCESSOR="${SCRIPT_DIR}/posix_compat_preprocessor.sh"

# Use unique temp directory to avoid race conditions in parallel builds
TEMP_DIR="${DAP_TPL_TEMP_DIR:-/tmp/dap_tpl_$$}"
mkdir -p "$TEMP_DIR"

# Clean up old temporary files in our unique directory
rm -f "$TEMP_DIR"/dap_tpl_simple_base.awk "$TEMP_DIR"/dap_tpl_engine*.awk

# Support parallel execution: use unique temp directory per process
# Use DAP_TPL_ENGINE_OUTPUT if set (legacy), otherwise engine is in TEMP_DIR
ENGINE_FINAL="${DAP_TPL_ENGINE_OUTPUT:-$TEMP_DIR/dap_tpl_engine.awk}"

echo "Step 1: Creating engine template with @include directives..."

# Use template and add construct definitions
ENGINE_WITH_INCLUDES="$TEMP_DIR/dap_tpl_simple_base.awk"
TEMPLATE="${SCRIPT_DIR}/engine_template.awk"

# Copy template
cp "$TEMPLATE" "$ENGINE_WITH_INCLUDES"

# Add construct definitions before @CONSTRUCT_DEFINITIONS@ marker
CONSTRUCTS_TEMP="$TEMP_DIR/dap_tpl_constructs.awk"
{
    for construct_dir in "$DAP_TPL_DIR/constructs"/*; do
        if [ -d "$construct_dir" ]; then
            construct_name=$(basename "$construct_dir")
            
            # Include ALL construct files in the right order
            # 1. Tokenizer (if exists)
            if [ -f "$construct_dir/tokenizer.awk" ]; then
                echo "BEGIN { DEBUG_FILE_NAME = \"${construct_name}_tokenizer\" }"
                echo "@include \"constructs/$construct_name/tokenizer.awk\""
            fi
            
            # 2. Parser (if exists)
            if [ -f "$construct_dir/parser.awk" ]; then
                echo "BEGIN { DEBUG_FILE_NAME = \"${construct_name}_parser\" }"
                echo "@include \"constructs/$construct_name/parser.awk\""
            fi
            
            # 2a. Branch parser (if exists)
            if [ -f "$construct_dir/branch_parser.awk" ]; then
                echo "BEGIN { DEBUG_FILE_NAME = \"${construct_name}_branch_parser\" }"
                echo "@include \"constructs/$construct_name/branch_parser.awk\""
            fi
            
            # 2b. Content parser (if exists)
            if [ -f "$construct_dir/content_parser.awk" ]; then
                echo "BEGIN { DEBUG_FILE_NAME = \"${construct_name}_content_parser\" }"
                echo "@include \"constructs/$construct_name/content_parser.awk\""
            fi
            
            # 3. Evaluator (if exists)
            if [ -f "$construct_dir/evaluator.awk" ]; then
                echo "BEGIN { DEBUG_FILE_NAME = \"${construct_name}_evaluator\" }"
                echo "@include \"constructs/$construct_name/evaluator.awk\""
            fi
            
            # 4. Helpers (if exists)
            if [ -f "$construct_dir/helpers.awk" ]; then
                echo "BEGIN { DEBUG_FILE_NAME = \"${construct_name}_helpers\" }"
                echo "@include \"constructs/$construct_name/helpers.awk\""
            fi
            
            # 5. Process (if exists)
            if [ -f "$construct_dir/process.awk" ]; then
                echo "BEGIN { DEBUG_FILE_NAME = \"${construct_name}_process\" }"
                echo "@include \"constructs/$construct_name/process.awk\""
            fi
            
            # 6. Render (if exists)
            if [ -f "$construct_dir/render.awk" ]; then
                echo "BEGIN { DEBUG_FILE_NAME = \"${construct_name}_render\" }"
                echo "@include \"constructs/$construct_name/render.awk\""
            fi
            
            # 7. Renderer (if exists - for backward compatibility)
            if [ -f "$construct_dir/renderer.awk" ]; then
                echo "BEGIN { DEBUG_FILE_NAME = \"${construct_name}_renderer\" }"
                echo "@include \"constructs/$construct_name/renderer.awk\""
            fi
            
            # 8. Definition (registration) - ALWAYS last
            if [ -f "$construct_dir/definition.awk" ]; then
                echo "BEGIN { DEBUG_FILE_NAME = \"${construct_name}_definition\" }"
                echo "@include \"constructs/$construct_name/definition.awk\""
            fi
        fi
    done
} > "$CONSTRUCTS_TEMP"

# Add mocking extensions if MOCKING_DIR is provided
MOCKING_DIR="$1"
if [ -n "$MOCKING_DIR" ] && [ -d "$MOCKING_DIR" ]; then
    echo "Adding mocking extensions from: $MOCKING_DIR"
    MOCKING_TEMP="$TEMP_DIR/dap_tpl_mocking.awk"
    MOCKING_DIR_ABS="$(cd "$MOCKING_DIR" && pwd)"
    MOCK_REL_PATH=$(realpath --relative-to="$DAP_TPL_DIR" "$MOCKING_DIR_ABS")
    {
        # Include loose .awk files at the mocking root level
        for mock_file in "$MOCKING_DIR"/*.awk; do
            [ -f "$mock_file" ] || continue
            mock_file_name=$(basename "$mock_file")
            echo "BEGIN { DEBUG_FILE_NAME = \"mock_${mock_file_name}\" }"
            echo "@include \"${MOCK_REL_PATH}/${mock_file_name}\""
        done

        for mock_dir in "$MOCKING_DIR"/*; do
            if [ -d "$mock_dir" ]; then
                mock_name=$(basename "$mock_dir")
                
                # Include ALL mock files in the right order (same as constructs)
                # 1. Tokenizer (if exists)
                if [ -f "$mock_dir/tokenizer.awk" ]; then
                    echo "BEGIN { DEBUG_FILE_NAME = \"mock_${mock_name}_tokenizer\" }"
                    echo "@include \"${MOCK_REL_PATH}/$mock_name/tokenizer.awk\""
                fi
                
                # 2. Parser (if exists)
                if [ -f "$mock_dir/parser.awk" ]; then
                    echo "BEGIN { DEBUG_FILE_NAME = \"mock_${mock_name}_parser\" }"
                    echo "@include \"${MOCK_REL_PATH}/$mock_name/parser.awk\""
                fi
                
                # 2a. Branch parser (if exists)
                if [ -f "$mock_dir/branch_parser.awk" ]; then
                    echo "BEGIN { DEBUG_FILE_NAME = \"mock_${mock_name}_branch_parser\" }"
                    echo "@include \"${MOCK_REL_PATH}/$mock_name/branch_parser.awk\""
                fi
                
                # 2b. Content parser (if exists)
                if [ -f "$mock_dir/content_parser.awk" ]; then
                    echo "BEGIN { DEBUG_FILE_NAME = \"mock_${mock_name}_content_parser\" }"
                    echo "@include \"${MOCK_REL_PATH}/$mock_name/content_parser.awk\""
                fi
                
                # 3. Evaluator (if exists)
                if [ -f "$mock_dir/evaluator.awk" ]; then
                    echo "BEGIN { DEBUG_FILE_NAME = \"mock_${mock_name}_evaluator\" }"
                    echo "@include \"${MOCK_REL_PATH}/$mock_name/evaluator.awk\""
                fi
                
                # 4. Helpers (if exists)
                if [ -f "$mock_dir/helpers.awk" ]; then
                    echo "BEGIN { DEBUG_FILE_NAME = \"mock_${mock_name}_helpers\" }"
                    echo "@include \"${MOCK_REL_PATH}/$mock_name/helpers.awk\""
                fi
                
                # 5. Process (if exists)
                if [ -f "$mock_dir/process.awk" ]; then
                    echo "BEGIN { DEBUG_FILE_NAME = \"mock_${mock_name}_process\" }"
                    echo "@include \"${MOCK_REL_PATH}/$mock_name/process.awk\""
                fi
                
                # 6. Render (if exists)
                if [ -f "$mock_dir/render.awk" ]; then
                    echo "BEGIN { DEBUG_FILE_NAME = \"mock_${mock_name}_render\" }"
                    echo "@include \"${MOCK_REL_PATH}/$mock_name/render.awk\""
                fi
                
                # 7. Renderer (if exists - for backward compatibility)
                if [ -f "$mock_dir/renderer.awk" ]; then
                    echo "BEGIN { DEBUG_FILE_NAME = \"mock_${mock_name}_renderer\" }"
                    echo "@include \"${MOCK_REL_PATH}/$mock_name/renderer.awk\""
                fi
                
                # 8. Definition (registration) - ALWAYS last
                if [ -f "$mock_dir/definition.awk" ]; then
                    echo "BEGIN { DEBUG_FILE_NAME = \"mock_${mock_name}_definition\" }"
                    echo "@include \"${MOCK_REL_PATH}/$mock_name/definition.awk\""
                fi
            fi
        done
    } > "$MOCKING_TEMP"
    
    # Append mocking extensions to constructs
    cat "$MOCKING_TEMP" >> "$CONSTRUCTS_TEMP"
    rm -f "$MOCKING_TEMP"
fi

# Replace marker with real includes
awk -v constructs_file="$CONSTRUCTS_TEMP" '
    /^# @CONSTRUCT_DEFINITIONS@/ {
        while ((getline line < constructs_file) > 0) {
            print line
        }
        close(constructs_file)
        next
    }
    { print }
' "$TEMPLATE" > "$ENGINE_WITH_INCLUDES"

rm -f "$CONSTRUCTS_TEMP"

echo "  Created: $ENGINE_WITH_INCLUDES"

# Step 2: Expand @include directives  
echo "Step 2: Expanding @include directives..."
ENGINE_EXPANDED="$TEMP_DIR/dap_tpl_engine_expanded.awk"
AWKPATH="${DAP_TPL_DIR}" "$PREPROCESSOR" "$ENGINE_WITH_INCLUDES" "${DAP_TPL_DIR}" > "$ENGINE_EXPANDED"

echo "  Expanded: $ENGINE_EXPANDED ($(wc -l < "$ENGINE_EXPANDED") lines)"

# Step 3: Process multidimensional for loops
echo "Step 3: Processing multidimensional for loops..."
ENGINE_MULTIDIM="$TEMP_DIR/dap_tpl_engine_multidim.awk"
"$MULTIDIM_FOR_PROCESSOR" "$ENGINE_EXPANDED" "$ENGINE_MULTIDIM"

echo "  Processed: $ENGINE_MULTIDIM"

# Step 4: Process indirect function calls
echo "Step 4: Processing indirect function calls..."
ENGINE_NO_INDIRECT="$TEMP_DIR/dap_tpl_engine_no_indirect.awk"
"$INDIRECT_PROCESSOR" "$ENGINE_MULTIDIM" "$ENGINE_NO_INDIRECT" "$DAP_TPL_DIR" "$MOCKING_DIR"

echo "  Processed: $ENGINE_NO_INDIRECT"

# Step 5: Normalize create_token calls
echo "Step 5: Normalizing create_token calls..."
ENGINE_NORMALIZED="$TEMP_DIR/dap_tpl_engine_normalized.awk"
"$NORMALIZE_CREATE_TOKEN" "$ENGINE_NO_INDIRECT" "$ENGINE_NORMALIZED"

echo "  Normalized: $ENGINE_NORMALIZED"

# Step 6: Apply POSIX compatibility layer
echo "Step 6: Applying POSIX compatibility layer..."
ENGINE_POSIX_COMPAT="$TEMP_DIR/dap_tpl_engine_posix_compat.awk"
"$POSIX_COMPAT_PROCESSOR" "$ENGINE_NORMALIZED" "$ENGINE_POSIX_COMPAT"

echo "  POSIX compatible: $ENGINE_POSIX_COMPAT"

# Step 7: Final engine
ENGINE_FINAL="$TEMP_DIR/dap_tpl_engine.awk"
cp "$ENGINE_POSIX_COMPAT" "$ENGINE_FINAL"

echo "  Engine: $ENGINE_FINAL"

# Step 8: Validate
if command -v mawk >/dev/null 2>&1; then
    echo "Step 8: Validating syntax with mawk..."
    if mawk -f "$ENGINE_FINAL" /dev/null 2>/dev/null; then
        echo "  ✓ Syntax validation passed!"
    else
        echo "  ✗ Syntax validation failed:"
        mawk -f "$ENGINE_FINAL" /dev/null 2>&1 | head -10
    fi
fi

# Cleanup intermediate temp files (keep only final engine)
rm -f "$ENGINE_WITH_INCLUDES" "$ENGINE_EXPANDED" "$ENGINE_MULTIDIM" "$ENGINE_NO_INDIRECT" "$ENGINE_NORMALIZED" "$ENGINE_POSIX_COMPAT" 2>/dev/null || true

echo ""
echo "✓ AWK engine built successfully!"
echo "ENGINE_PATH=$ENGINE_FINAL"
