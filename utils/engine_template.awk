# AUTO-GENERATED DAP TPL Engine Template
# This file contains @include directives that will be expanded by the preprocessor

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

# Construct definitions - will be added dynamically by build script
# @CONSTRUCT_DEFINITIONS@

# Main pipeline
BEGIN { DEBUG_FILE_NAME = "main_pipeline" }
@include "core/main_pipeline.awk"
