{{#for entry in FUNCTIONS_DATA|newline}}
    {{entry|split|pipe}}
    Function: {{entry|part|1}}
    Return type: {{entry|part|0}}
{{/for}}
