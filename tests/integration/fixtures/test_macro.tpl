{{#macro GREETING}}
Hello, {{ARG0}}! Welcome to {{ARG1}}.
{{/macro}}

{{#call GREETING|World|DAP TPL}}

{{#macro CONDITIONAL}}
{{#if ARG0}}
Value is true: {{ARG1}}
{{else}}
Value is false: {{ARG1}}
{{/if}}
{{/macro}}

{{#call CONDITIONAL|1|test}}
