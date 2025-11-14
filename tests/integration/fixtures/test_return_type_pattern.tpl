{{#for type in RETURN_TYPES}}
    {{#set macro_name={{type|sanitize_name}}}}
    {{#if macro_name}}
        // Specialized macro for return type: {{type}}
        {{#if type == 'void'}}
            #define _DAP_MOCK_WRAPPER_CUSTOM_SELECT_{{macro_name}}(func_name, return_type_full, ...) \
                _DAP_MOCK_WRAPPER_CUSTOM_VOID(func_name, __VA_ARGS__)
        {{else}}
            #define _DAP_MOCK_WRAPPER_CUSTOM_SELECT_{{macro_name}}(func_name, return_type_full, ...) \
                _DAP_MOCK_WRAPPER_CUSTOM_NONVOID(return_type_full, func_name, ##__VA_ARGS__)
        {{/if}}
    {{/if}}
{{/for}}
