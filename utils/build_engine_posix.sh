#!/bin/sh
# POSIX AWK Build Engine Script - Simplified version
# Creates engine file with @include directives, then expands them

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAP_TPL_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PREPROCESSOR="${SCRIPT_DIR}/awk_include_preprocessor.sh"
INDIRECT_PROCESSOR="${SCRIPT_DIR}/indirect_call_processor.sh"
MULTIDIM_FOR_PROCESSOR="${SCRIPT_DIR}/multidim_for_preprocessor.sh"

echo "Step 1: Creating engine template with @include directives..."

# Create simple engine file with @include directives
ENGINE_WITH_INCLUDES="/tmp/dap_tpl_simple_base.awk"
cat > "$ENGINE_WITH_INCLUDES" << 'AWK_HEADER'
# AUTO-GENERATED DAP TPL Engine
# Core includes
BEGIN { DEBUG_FILE_NAME = "token_tree" }
@include "core/token_tree.awk"
BEGIN { DEBUG_FILE_NAME = "variable_context" }
@include "core/variable_context.awk"
BEGIN { DEBUG_FILE_NAME = "macro_store" }
@include "core/macro_store.awk"
BEGIN { DEBUG_FILE_NAME = "renderer" }
@include "core/renderer.awk"
BEGIN { DEBUG_FILE_NAME = "construct_registry" }
@include "core/construct_registry.awk"
BEGIN { DEBUG_FILE_NAME = "marker_utils" }
@include "core/marker_utils.awk"
BEGIN { DEBUG_FILE_NAME = "tokenizer_helpers" }
@include "core/tokenizer_helpers.awk"
BEGIN { DEBUG_FILE_NAME = "metadata_helpers" }
@include "core/metadata_helpers.awk"
BEGIN { DEBUG_FILE_NAME = "child_helpers" }
@include "core/child_helpers.awk"
BEGIN { DEBUG_FILE_NAME = "generic_branch_parser" }
@include "core/generic_branch_parser.awk"
BEGIN { DEBUG_FILE_NAME = "conditional_evaluator_helpers" }
@include "core/conditional_evaluator_helpers.awk"
BEGIN { DEBUG_FILE_NAME = "sh_section_extensions" }
@include "core/sh_section_extensions.awk"

# Helper includes
BEGIN { DEBUG_FILE_NAME = "marker_parser" }
@include "core/marker_parser.awk"
BEGIN { DEBUG_FILE_NAME = "condition_parser" }
@include "core/condition_parser.awk"
BEGIN { DEBUG_FILE_NAME = "variable_functions" }
@include "core/variable_functions.awk"
BEGIN { DEBUG_FILE_NAME = "variable_replacer" }
@include "core/variable_replacer.awk"
BEGIN { DEBUG_FILE_NAME = "construct_replacer" }
@include "core/construct_replacer.awk"
BEGIN { DEBUG_FILE_NAME = "evaluator_core" }
@include "core/evaluator_core.awk"
BEGIN { DEBUG_FILE_NAME = "tokenizer_core" }
@include "core/tokenizer_core.awk"
BEGIN { DEBUG_FILE_NAME = "safety_checks" }
@include "core/safety_checks.awk"
BEGIN { DEBUG_FILE_NAME = "load_constructs" }
@include "core/load_constructs.awk"
BEGIN { DEBUG_FILE_NAME = "debug" }
@include "core/debug.awk"

# Construct definitions
AWK_HEADER

# Add all construct definitions
for construct_dir in "$DAP_TPL_DIR/constructs"/*; do
    if [ -d "$construct_dir" ] && [ -f "$construct_dir/definition.awk" ]; then
        construct_name=$(basename "$construct_dir")
        echo "BEGIN { DEBUG_FILE_NAME = \"$construct_name\" }" >> "$ENGINE_WITH_INCLUDES"
        echo "@include \"constructs/$construct_name/definition.awk\"" >> "$ENGINE_WITH_INCLUDES"
    fi
done

# Add main pipeline
cat >> "$ENGINE_WITH_INCLUDES" << 'AWK_FOOTER'

# Main pipeline
BEGIN { DEBUG_FILE_NAME = "main_pipeline" }
@include "core/main_pipeline.awk"
AWK_FOOTER

echo "  Created: $ENGINE_WITH_INCLUDES"

# Step 2: Expand @include directives  
echo "Step 2: Expanding @include directives..."
ENGINE_EXPANDED="/tmp/dap_tpl_engine_expanded.awk"
AWKPATH="${DAP_TPL_DIR}" "$PREPROCESSOR" "$ENGINE_WITH_INCLUDES" "${DAP_TPL_DIR}" > "$ENGINE_EXPANDED"

echo "  Expanded: $ENGINE_EXPANDED ($(wc -l < "$ENGINE_EXPANDED") lines)"

# Step 3: Process indirect function calls
echo "Step 3: Processing indirect function calls..."
ENGINE_NO_INDIRECT="/tmp/dap_tpl_engine_no_indirect.awk"
"$INDIRECT_PROCESSOR" "$ENGINE_EXPANDED" "$ENGINE_NO_INDIRECT"

echo "  Processed: $ENGINE_NO_INDIRECT"

# Step 4: Final POSIX engine
ENGINE_POSIX="/tmp/dap_tpl_engine_posix.awk"
cp "$ENGINE_NO_INDIRECT" "$ENGINE_POSIX"

echo "  POSIX engine: $ENGINE_POSIX"

# Step 5: Validate
if command -v mawk >/dev/null 2>&1; then
    echo "Step 4: Validating syntax with mawk..."
    if mawk -f "$ENGINE_POSIX" /dev/null 2>/dev/null; then
        echo "  ✓ Syntax validation passed!"
    else
        echo "  ✗ Syntax validation failed:"
        mawk -f "$ENGINE_POSIX" /dev/null 2>&1 | head -10
    fi
fi

echo ""
echo "✓ POSIX AWK engine built successfully!"
echo "ENGINE_PATH=$ENGINE_POSIX"
