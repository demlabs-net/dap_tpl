{{#if VAR1 && VAR2}}
Both are true
{{else}}
At least one is false
{{/if}}

{{#if VAR1 || VAR2}}
At least one is true
{{else}}
Both are false
{{/if}}

{{#if !VAR1}}
VAR1 is false
{{else}}
VAR1 is true
{{/if}}
