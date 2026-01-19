# Condition System Loader
# Loads all condition parsers and evaluators
# This file acts as a registry for all condition types
# Note: This file is processed by build_engine.sh which adds DEBUG_FILE_NAME
# before each condition module include. The @include directives are handled
# by build_engine.sh, not by this file directly.
#
# When used outside build_engine.sh (e.g., in tests), the @include directives
# below will be used. But in the compiled engine, build_engine.sh replaces
# this section with individual includes that have DEBUG_FILE_NAME set.

# Include all logical operators
@include "conditions/logical/and/parser.awk"
@include "conditions/logical/and/evaluator.awk"
@include "conditions/logical/or/parser.awk"
@include "conditions/logical/or/evaluator.awk"
@include "conditions/logical/not/parser.awk"
@include "conditions/logical/not/evaluator.awk"

# Include comparison operators (unified)
@include "conditions/comparison/parser.awk"
@include "conditions/comparison/evaluator.awk"

# Include special operators
@include "conditions/special/contains/parser.awk"
@include "conditions/special/contains/evaluator.awk"
@include "conditions/special/not_contains/parser.awk"
@include "conditions/special/not_contains/evaluator.awk"
@include "conditions/special/in/parser.awk"
@include "conditions/special/in/evaluator.awk"
@include "conditions/special/matches/parser.awk"
@include "conditions/special/matches/evaluator.awk"

# Include simple variable
@include "conditions/simple/parser.awk"
@include "conditions/simple/evaluator.awk"

