# Condition System Loader
# Loads all condition parsers and evaluators
# This file acts as a registry for all condition types

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
@include "conditions/special/in/parser.awk"
@include "conditions/special/in/evaluator.awk"
@include "conditions/special/matches/parser.awk"
@include "conditions/special/matches/evaluator.awk"

# Include simple variable
@include "conditions/simple/parser.awk"
@include "conditions/simple/evaluator.awk"

