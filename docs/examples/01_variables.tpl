// Example 1: Variables and Functions
// Demonstrates: variable substitution, split, part, trim, contains

// Simple variable
Module: {{MODULE_NAME}}

// Variable with split function
{{#set FULL_TYPE=dap_list_t*|int|char*}}
Types in list:
{{FULL_TYPE|split|pipe}}

// Getting specific parts
First type: {{FULL_TYPE|part|0}}
Second type: {{FULL_TYPE|part|1}}
Third type: {{FULL_TYPE|part|2}}

// Trimming whitespace
{{#set PADDED_VALUE=   hello world   }}
Original: [{{PADDED_VALUE}}]
Trimmed: [{{PADDED_VALUE|trim}}]

// Substring check
{{#set TEXT=This is a test string}}
{{#if TEXT|contains|test}}
Text contains 'test'
{{/if}}

// Not equal check
{{#set VALUE=42}}
{{#if VALUE|ne|0}}
Value is not zero
{{/if}}

