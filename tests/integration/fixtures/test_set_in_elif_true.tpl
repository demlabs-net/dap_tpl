{{#if COND == 0}}
{{#set VALUE=100}}
If value: {{VALUE}}
{{#elif COND == 1}}
{{#set VALUE=50}}
Elif value: {{VALUE}}
{{else}}
{{#set VALUE=99}}
Else value: {{VALUE}}
{{/if}}

