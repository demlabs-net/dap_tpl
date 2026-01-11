// Test template for nested {{#for}} inside {{#if}} with file-based data

{{#if NORMALIZATION_MACROS_DATA}}
    {{#for entry in NORMALIZATION_MACROS_DATA|newline}}
        {{entry|split|pipe}}
        {{#set macro_key={{entry|part|0}}}}
        {{#set base_type={{entry|part|1}}}}
        
        // Macro key: {{macro_key}}, Base type: {{base_type}}
        #define TEST_MACRO_{{macro_key}} {{base_type}}
        
    {{/for}}
{{/if}}

// End of template

