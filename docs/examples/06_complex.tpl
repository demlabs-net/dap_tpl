// Example 6: Complex Template
// Demonstrates: combination of all features

{{! This is a comment - it will not appear in output }}

{{#macro MOCK_FUNCTION}}
{{! Define a mock function with proper signature }}
/**
 * Mock for {{ARG0}}
 */
{{#if ARG1 contains '*'}}
{{! Pointer type }}
{{ARG1|normalize_name}} mock_{{ARG0}}({{ARG2}}) {
    {{#if ARG1 == void*}}
    return NULL;
    {{else}}
    static {{ARG1}} result;
    return &result;
    {{/if}}
}
{{#elif ARG1 == void}}
{{! Void return type }}
void mock_{{ARG0}}({{ARG2}}) {
    // Mock implementation
}
{{else}}
{{! Value type }}
{{ARG1}} mock_{{ARG0}}({{ARG2}}) {
    return ({{ARG1}})0;
}
{{/if}}
{{/macro}}

// Generate header
#ifndef {{MODULE|sanitize_name}}_MOCKS_H
#define {{MODULE|sanitize_name}}_MOCKS_H

{{#if MOCK_LIST}}
{{! Process mock list }}
{{#for mock_entry in MOCK_LIST}}
{{#set PARTS={{mock_entry}}}}
{{PARTS|split|pipe}}
{{#set FUNC_NAME={{PARTS|part|0}}}}
{{#set RETURN_TYPE={{PARTS|part|1}}}}
{{#set PARAMS={{PARTS|part|2}}}}

{{#call MOCK_FUNCTION|{{FUNC_NAME}}|{{RETURN_TYPE}}|{{PARAMS}}}}
{{/for}}
{{else}}
// No mocks defined
{{/if}}

{{!-- Multi-line comment
This shows how to use all features together:
- Macros for reusable code
- Conditionals for different cases
- Loops for processing lists
- Variable functions for transformations
- Includes for modularity
--}}

#endif // {{MODULE|sanitize_name}}_MOCKS_H

