{{#for type in RETURN_TYPES}}
    Type: {{type}}
    {{#if type == 'void'}}
        VOID BRANCH: {{type}}
    {{else}}
        NON-VOID BRANCH: {{type}}
    {{/if}}
{{/for}}
