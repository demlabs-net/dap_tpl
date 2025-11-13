// Example 3: Loops
// Demonstrates: for loops, nested loops, loop with conditionals

// Simple loop with pipe-separated list
{{#set TYPES=int|char*|dap_list_t*}}
{{#for type in TYPES}}
typedef {{type}} type_{{type|normalize_name}}_t;
{{/for}}

// Loop with newline-separated list
{{#set FUNCTIONS=init
cleanup
process
execute}}
{{#for func in FUNCTIONS}}
int dap_{{func}}(void);
{{/for}}

// Nested loops
{{#set OUTER=A|B|C}}
{{#set INNER=1|2|3}}
{{#for outer in OUTER}}
{{#for inner in INNER}}
#define MACRO_{{outer}}_{{inner}} {{outer}}{{inner}}
{{/for}}
{{/for}}

// Loop with conditionals
{{#set PARAMS=name|age|address|phone}}
{{#for param in PARAMS}}
{{#if param == name}}
    // Name is required
    const char* {{param}};  // Required
{{#elif param == age}}
    int {{param}};  // Optional
{{else}}
    const char* {{param}};  // Optional
{{/if}}
{{/for}}

// Loop with variable functions
{{#set DATA=dap_list_t*|ptr=LIST
int|value=42
char*|ptr=STR}}
{{#for entry in DATA}}
{{#set PARTS={{entry}}}}
{{PARTS|split|pipe}}
Type: {{PARTS|part|0}}, Default: {{PARTS|part|1}}
{{/for}}

