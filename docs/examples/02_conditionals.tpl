// Example 2: Conditionals
// Demonstrates: if/elif/else, comparisons, logical operators
// See: docs/DAP_TPL_GUIDE.md#conditionals

// Simple boolean check
{{#if ENABLE_FEATURE}}
#define FEATURE_ENABLED
{{/if}}

// Comparison operators
{{#if COUNT == 0}}
// No items
{{#elif COUNT == 1}}
// One item
{{#elif COUNT > 10}}
// Many items (more than 10)
{{#elif COUNT >= 5}}
// Several items (5-10)
{{else}}
// Few items (2-4)
{{/if}}

// Logical AND
{{#if HAS_POINTER && HAS_CONST}}
// Type is const pointer
typedef const {{BASE_TYPE}}* {{TYPE_NAME}};
{{/if}}

// Logical OR
{{#if IS_DEBUG || IS_VERBOSE}}
#define ENABLE_LOGGING
{{/if}}

// Logical NOT
{{#if !IS_PRODUCTION}}
#define DEBUG_MODE
{{/if}}

// Substring check
{{#if TYPE contains '*'}}
// Type is a pointer
{{TYPE|normalize_name}}
{{/if}}

// Combined conditions
{{#if (COUNT > 0) && (TYPE contains 'dap_')}}
// Valid DAP type with elements
#include "{{TYPE}}.h"
{{/if}}

