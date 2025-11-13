// Example 4: Macros
// Demonstrates: macro definition, macro calls, parameters, conditional macros
// See: docs/DAP_TPL_GUIDE.md#macros

// Simple macro
{{#macro HEADER_GUARD}}
#ifndef {{ARG0}}_H
#define {{ARG0}}_H
{{/macro}}

{{#call HEADER_GUARD|DAP_TEST}}

// Macro with multiple parameters
{{#macro DECLARE_FUNCTION}}
/**
 * @brief {{ARG0}}
 * @param {{ARG1}}
 * @return {{ARG2}}
 */
{{ARG2}} {{ARG0}}({{ARG1}});
{{/macro}}

{{#call DECLARE_FUNCTION|dap_init|void|int}}
{{#call DECLARE_FUNCTION|dap_process|const char* data|dap_result_t}}

// Macro with conditional logic
{{#macro TYPE_DEFINITION}}
{{#if ARG1}}
typedef {{ARG0}} {{ARG1}}_t;
{{else}}
typedef {{ARG0}} generic_type_t;
{{/if}}
{{/macro}}

{{#call TYPE_DEFINITION|int|counter}}
{{#call TYPE_DEFINITION|char*|string}}
{{#call TYPE_DEFINITION|void*|}}

// Macro with loops
{{#macro DEFINE_ENUM}}
typedef enum {{ARG0}} {
{{#set VALUES={{ARG1}}}}
{{#for value in VALUES}}
    {{ARG0}}_{{value|sanitize_name}},
{{/for}}
} {{ARG0}}_t;
{{/macro}}

{{#call DEFINE_ENUM|dap_status|SUCCESS|ERROR|PENDING}}

// Nested macro calls
{{#macro WRAPPER}}
{{#call HEADER_GUARD|{{ARG0}}}}
// Content for {{ARG0}}
#endif // {{ARG0}}_H
{{/macro}}

{{#call WRAPPER|DAP_WRAPPER}}

