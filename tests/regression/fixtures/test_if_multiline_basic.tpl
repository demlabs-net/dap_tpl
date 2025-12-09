{{#if MAP_IMPL_COND_DATA}}
Variable is NOT empty
{{#for entry in MAP_IMPL_COND_DATA|newline}}
Entry: {{entry}}
{{/for}}
{{else}}
Variable IS empty
{{/if}}
