{{#for entry in FUNCTIONS_DATA|newline}}
    {{entry|split|pipe}}
    {{#set return_type={{entry|part|0}}}}
    {{#set func_name={{entry|part|1}}}}
    {{#if func_name}}
        // Wrapper for function: {{func_name}}
        // Return type: {{return_type}}
        #define _DAP_MOCK_WRAPPER_CUSTOM_FOR_{{func_name}}(return_type_full, ...) \
            extern return_type_full __real_{{func_name}}(_DAP_MOCK_MAP(_DAP_MOCK_PARAM_DECL, ##__VA_ARGS__)); \
            static return_type_full __mock_impl_{{func_name}}(_DAP_MOCK_MAP(_DAP_MOCK_PARAM_DECL, ##__VA_ARGS__)); \
            return_type_full __wrap_{{func_name}}(_DAP_MOCK_MAP(_DAP_MOCK_PARAM_DECL, ##__VA_ARGS__))
    {{/if}}
{{/for}}
