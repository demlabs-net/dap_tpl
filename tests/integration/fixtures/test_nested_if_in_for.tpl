{{#for type in RETURN_TYPES}}
    {{#set macro_name={{type|sanitize_name}}}}
    {{#if macro_name}}
        // Processing type: {{type}}
        {{#if type == 'void'}}
            VOID_BRANCH: {{type}}
        {{else}}
            NON_VOID_BRANCH: {{type}}
        {{/if}}
    {{/if}}
{{/for}}
