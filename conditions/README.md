# Condition System - Modular Architecture

## Overview

The condition system has been refactored into a modular architecture where each condition type has its own parser and evaluator.

## Structure

```
conditions/
├── condition_loader.awk       # Main loader for all condition modules
├── logical/                   # Logical operators
│   ├── and/
│   │   ├── parser.awk        # Parses: left && right
│   │   └── evaluator.awk     # Evaluates AND logic
│   ├── or/
│   │   ├── parser.awk        # Parses: left || right
│   │   └── evaluator.awk     # Evaluates OR logic
│   └── not/
│       ├── parser.awk         # Parses: !expr
│       └── evaluator.awk      # Evaluates NOT logic
├── comparison/                # Comparison operators
│   ├── parser.awk             # Parses: ==, !=, >, <, >=, <=
│   └── evaluator.awk          # Evaluates comparisons
├── special/                   # Special operators
│   ├── contains/
│   │   ├── parser.awk         # Parses: left contains 'text'
│   │   └── evaluator.awk      # Evaluates contains
│   ├── in/
│   │   ├── parser.awk         # Parses: left in list
│   │   └── evaluator.awk      # Evaluates in list
│   └── matches/
│       ├── parser.awk         # Parses: left matches 'pattern'
│       └── evaluator.awk      # Evaluates regex match
└── simple/                    # Simple variable
    ├── parser.awk             # Parses: VAR
    └── evaluator.awk          # Evaluates truthiness
```

## Usage

The main entry point is still `core/condition_parser.awk`, which now includes `conditions/condition_loader.awk` to load all condition modules.

### Parser Functions

Each condition type provides a parser function:
- `parse_logical_and(expr)` - parses `&&` expressions
- `parse_logical_or(expr)` - parses `||` expressions
- `parse_logical_not(expr)` - parses `!` expressions
- `parse_comparison(expr, op, pos, len)` - parses comparison operators
- `parse_contains(expr)` - parses `contains` expressions
- `parse_in_list(expr)` - parses `in` expressions
- `parse_matches(expr)` - parses `matches` expressions
- `parse_simple_var(expr)` - parses simple variables

### Evaluator Functions

Each condition type provides an evaluator function:
- `evaluate_logical_and(parts)` - evaluates AND
- `evaluate_logical_or(parts)` - evaluates OR
- `evaluate_logical_not(parts)` - evaluates NOT
- `evaluate_comparison(op, parts)` - evaluates comparisons
- `evaluate_contains(parts)` - evaluates contains
- `evaluate_in_list(parts)` - evaluates in
- `evaluate_matches(parts)` - evaluates matches
- `evaluate_simple_var(parts)` - evaluates simple variable

## Testing

All tests are located in `tests/unit/conditions/`:

```
tests/unit/conditions/
├── logical/
│   └── test_and_parser.awk
├── comparison/
│   └── test_comparison_parser.awk
├── special/
│   ├── test_contains_parser.awk
│   └── test_matches_parser.awk
├── simple/
│   └── test_simple_parser.awk
├── integration/
│   └── test_condition_integration.awk
└── run_all_condition_tests.sh
```

Run all tests:
```bash
cd dap_tpl
./tests/unit/conditions/run_all_condition_tests.sh
```

## Benefits of Modular Architecture

1. **Single Responsibility** - Each module handles one condition type
2. **Easy to Extend** - Add new condition types by creating new modules
3. **Testable** - Each module can be tested independently
4. **Maintainable** - Changes to one condition type don't affect others
5. **Clear Structure** - Easy to navigate and understand

## Adding New Condition Types

To add a new condition type:

1. Create directory: `conditions/new_type/`
2. Create `parser.awk` with `parse_new_type()` function
3. Create `evaluator.awk` with `evaluate_new_type()` function
4. Add includes to `conditions/condition_loader.awk`
5. Add parsing logic to `core/condition_parser.awk` in `parse_condition()`
6. Add evaluation logic to `core/condition_parser.awk` in `evaluate_parsed_condition()`
7. Create tests in `tests/unit/conditions/new_type/`
8. Update `run_all_condition_tests.sh`

