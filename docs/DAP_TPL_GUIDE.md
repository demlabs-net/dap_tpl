# DAP Template Processing Language - Complete Guide

**Languages:** [English](DAP_TPL_GUIDE.md) | [Русский](DAP_TPL_GUIDE.ru.md)

**Navigation:** [🏠 README](../README.md) | [📚 Examples](examples/)

## Table of Contents

1. [Introduction](#introduction)
2. [Tutorial](#tutorial)
   - Lesson 1: Your First Template
   - Lesson 2: Using Conditionals
   - Lesson 3: Loops
   - Lesson 4: Macros for Reusability
   - Lesson 5: Putting It All Together
3. [Language Reference](#language-reference)
   - Variables
   - Conditionals
   - Loops
   - Macros
   - Includes
   - Comments
   - AWK/Shell Sections
4. [Cookbook](#cookbook)
   - 6 Practical Recipes
5. [Command-Line Tools](#command-line-tools)
   - dap_tpl.sh Reference
   - dap_tpl_lib.sh Reference
6. [API Reference](#api-reference)
7. [Advanced Topics](#advanced-topics)
   - Creating Custom Constructs
   - Extension System
   - Performance Optimization
   - Debugging
8. [Construct Index](#construct-index)
9. [Appendices](#appendices)
10. [Quick Reference Card](#quick-reference-card)

---

## Introduction

DAP TPL is a powerful template processing system designed for generating C code in the DAP SDK test framework. It provides a rich templating language with variables, conditionals, loops, macros, and more.

### Key Concepts

- **Templates** - Text files with embedded directives (`.tpl` extension)
- **Variables** - Placeholders replaced with values
- **Constructs** - Control structures like `if`, `for`, `macro`
- **Functions** - Transformations applied to variables
- **Tokens** - Internal AST representation
- **Engine** - Compiled AWK program that processes templates

### Design Philosophy

- **Modular** - Each feature is a separate plugin
- **Composable** - Features work together seamlessly
- **Extensible** - Easy to add new constructs
- **Testable** - Complete test coverage

---

## Tutorial

### Lesson 1: Your First Template

Create `hello.tpl`:
```
Hello, {{NAME}}!
Welcome to {{PROJECT}}.
```

Process it:
```bash
source dap_tpl/dap_tpl.sh
replace_template_placeholders hello.tpl output.txt "NAME=World" "PROJECT=DAP TPL"
```

Output:
```
Hello, World!
Welcome to DAP TPL.
```

### Lesson 2: Using Conditionals

Create `conditional.tpl`:
```
{{#if ENABLE_DEBUG}}
#define DEBUG_MODE
{{else}}
#undef DEBUG_MODE
{{/if}}
```

Process:
```bash
replace_template_placeholders conditional.tpl output.h "ENABLE_DEBUG=1"
```

### Lesson 3: Loops

Create `loop.tpl`:
```
{{#set TYPES=int|char*|void*}}
{{#for type in TYPES}}
typedef {{type}} my_{{type}}_t;
{{/for}}
```

### Lesson 4: Macros for Reusability

Create `macros.tpl`:
```
{{#macro DECLARE_GETTER}}
{{ARG0}} get_{{ARG1}}(void);
{{/macro}}

{{#call DECLARE_GETTER|int|count}}
{{#call DECLARE_GETTER|const char*|name}}
```

### Lesson 5: Putting It All Together

Combine all features in a real template:

```
{{#macro MOCK_FUNCTION}}
{{ARG0}} mock_{{ARG1}}({{ARG2}}) {
    {{#if ARG0 contains '*'}}
    return NULL;
    {{#elif ARG0 == void}}
    // No return
    {{else}}
    return 0;
    {{/if}}
}
{{/macro}}

{{#set FUNCTIONS=init|int|void
cleanup|void|void
get_data|char*|int id}}

{{#for func in FUNCTIONS}}
{{func|split|pipe}}
{{#call MOCK_FUNCTION|{{func|part|0}}|{{func|part|1}}|{{func|part|2}}}}
{{/for}}
```

See [docs/examples/06_complex.tpl](examples/06_complex.tpl) for a complete real-world example.

---

## Language Reference

### Variables

#### Syntax
```
{{VARIABLE_NAME}}
{{VARIABLE|function|argument}}
```

#### Available Functions

**String Operations:**
- `trim` - Remove leading/trailing whitespace
- `contains|substring` - Check if contains substring
- `split|delimiter` - Split into parts (use `pipe` or `newline`)
- `part|index` - Get part by index after split
- `replace|pattern|replacement` - Replace all occurrences of pattern with replacement
- `remove_suffix|suffix` - Remove suffix from string

**Comparison:**
- `ne|value` - Not equal to value
- `in_list` - Check if value is in a list

#### Examples
```
{{NAME}}                          → value of NAME
{{NAME|trim}}                     → trimmed value
{{LIST|split|pipe}}               → split by |
{{LIST|part|0}}                   → first element
{{VALUE|ne|0}}                    → check if not zero
{{TEXT|contains|test}}            → check if contains "test"
```

**Note:** Additional variable functions may be available through extensions (e.g., `normalize_name`, `escape_name`, `sanitize_name` from mocking extensions).

### Conditionals

#### if/elif/else

**Syntax:**
```
{{#if CONDITION}}
  content when true
{{#elif ANOTHER_CONDITION}}
  content when first is false and this is true
{{else}}
  content when all false
{{/if}}
```

#### Condition Types

**Boolean:**
```
{{#if VAR}}              - True if VAR is non-empty and not "0"
{{#if !VAR}}             - True if VAR is empty or "0"
```

**Comparison:**
```
{{#if VAR == value}}     - Equal
{{#if VAR != value}}     - Not equal
{{#if VAR > 5}}          - Greater than
{{#if VAR >= 5}}         - Greater or equal
{{#if VAR < 5}}          - Less than
{{#if VAR <= 5}}         - Less or equal
```

**String Operations:**
```
{{#if VAR contains 'text'}}    - Contains substring
{{#if VAR matches 'pattern'}}  - Matches regex
{{#if VAR in LIST}}            - In list
```

**Logical:**
```
{{#if VAR1 && VAR2}}     - Logical AND
{{#if VAR1 || VAR2}}     - Logical OR
{{#if !VAR}}             - Logical NOT
```

#### Examples
```
{{#if COUNT > 0}}
Has items: {{COUNT}}
{{/if}}

{{#if TYPE contains '*'}}
Pointer type: {{TYPE}}
{{/if}}

{{#if DEBUG && VERBOSE}}
Full logging enabled
{{/if}}
```

### Loops

#### for Loop

**Syntax:**
```
{{#for ITEM_VAR in LIST_VAR}}
  content using {{ITEM_VAR}}
{{/for}}
```

**List Separators:**
- Pipe: `item1|item2|item3`
- Newline: multiline lists

#### Examples
```
{{#set TYPES=int|char*|void*}}
{{#for type in TYPES}}
Type: {{type}}
{{/for}}

{{#set NAMES=alice
bob
charlie}}
{{#for name in NAMES}}
Name: {{name}}
{{/for}}
```

### Variable Assignment

#### set

**Syntax:**
```
{{#set VAR=value}}
{{#set VAR={{OTHER_VAR}}}}
```

#### Scope

Variables are scoped to the current block and nested blocks.

#### Examples
```
{{#set COUNTER=0}}
{{#set TYPE=dap_list_t*}}
{{#set NAME={{BASE_NAME}}_wrapper}}
```

### Macros

#### Macro Definition

**Syntax:**
```
{{#macro MACRO_NAME}}
  template content with {{ARG0}}, {{ARG1}}, ...
{{/macro}}
```

#### Macro Call

**Syntax:**
```
{{#call MACRO_NAME|arg1|arg2|arg3}}
```

#### Parameters

- `{{ARG0}}` - First argument
- `{{ARG1}}` - Second argument
- `{{ARG2}}` - Third argument
- etc.

#### Examples
```
{{#macro GETTER}}
{{ARG0}} get_{{ARG1}}() {
    return m_{{ARG1}};
}
{{/macro}}

{{#call GETTER|int|count}}
{{#call GETTER|const char*|name}}
```

### Includes

#### Template Include

**Syntax:**
```
{{#include "filename.tpl"}}
```

Templates (`.tpl` extension) are processed recursively with current variables.

#### Regular File Include

**Syntax:**
```
{{#include "filename.h"}}
```

Non-template files are included as-is.

#### Examples
```
{{#include "common_header.tpl"}}
{{#include "types.h"}}
```

### Comments

#### Single-line

**Syntax:**
```
{{! comment text }}
```

#### Multi-line

**Syntax:**
```
{{!--
multi-line
comment
--}}
```

Comments are removed from output.

### AWK Sections

#### Syntax
```
{{AWK:}}
AWK code here
{{/AWK}}
```

#### Example
```
{{AWK:}}
BEGIN {
    for (i = 0; i < 10; i++) {
        print "#define ITEM_" i " " i
    }
}
{{/AWK}}
```

### Shell Sections

#### Syntax
```
{{SH:}}
shell commands here
{{/SH}}
```

#### Example
```
{{SH:}}
echo "// Generated: $(date)"
echo "// User: $(whoami)"
{{/SH}}
```

---

## Cookbook

### Recipe 1: Generate Enum from List

```
{{#set VALUES=SUCCESS|ERROR|PENDING|TIMEOUT}}
typedef enum {
{{#for value in VALUES}}
    STATUS_{{value}},
{{/for}}
} status_t;
```

### Recipe 2: Conditional Compilation

```
{{#if PLATFORM == linux}}
#include <linux/types.h>
{{#elif PLATFORM == windows}}
#include <windows.h>
{{else}}
#include <stdint.h>
{{/if}}
```

### Recipe 3: Generate Function Declarations

```
{{#macro DECLARE}}
{{ARG0}} {{ARG1}}({{ARG2}});
{{/macro}}

{{#set FUNCTIONS=int|init|void
void|cleanup|void
char*|get_name|const char* id}}

{{#for func in FUNCTIONS}}
{{func|split|pipe}}
{{#call DECLARE|{{func|part|0}}|{{func|part|1}}|{{func|part|2}}}}
{{/for}}
```

### Recipe 4: Generate Type-safe Wrappers

```
{{#set TYPES=int|char*|dap_list_t*}}
{{#for type in TYPES}}
{{#set TYPE_NAME={{type|replace|*|_ptr|replace| |_}}}}
typedef struct {
    {{type}} value;
    int is_valid;
} safe_{{TYPE_NAME}}_t;

safe_{{TYPE_NAME}}_t* create_{{TYPE_NAME}}({{type}} val) {
    safe_{{TYPE_NAME}}_t* result = malloc(sizeof(safe_{{TYPE_NAME}}_t));
    result->value = val;
    result->is_valid = 1;
    return result;
}
{{/for}}
```

**Note:** For C-specific name normalization (e.g., `normalize_name`), use mocking extensions.

### Recipe 5: Conditional Mock Generation

```
{{#if CUSTOM_MOCKS_LIST}}
{{#for mock in CUSTOM_MOCKS_LIST}}
{{mock|split|pipe}}
{{#set FUNC={{mock|part|0}}}}
{{#set RETURN={{mock|part|1}}}}
#define MOCK_{{FUNC}} mock_{{FUNC}}
extern {{RETURN}} mock_{{FUNC}}(void);
{{/for}}
{{else}}
// No custom mocks
{{/if}}
```

### Recipe 6: Nested Data Processing

```
{{#set DATA=name:string:John
age:int:30
city:string:NYC}}

{{#for entry in DATA}}
{{entry|split|:}}
{{#set FIELD={{entry|part|0}}}}
{{#set TYPE={{entry|part|1}}}}
{{#set DEFAULT={{entry|part|2}}}}

{{#if TYPE == string}}
const char* {{FIELD}} = "{{DEFAULT}}";
{{#elif TYPE == int}}
int {{FIELD}} = {{DEFAULT}};
{{/if}}
{{/for}}
```

---

## Command-Line Tools

### dap_tpl.sh

Main library for template processing.

**Location:** `dap_tpl/dap_tpl.sh`

#### Usage

```bash
# Source the library
source dap_tpl/dap_tpl.sh

# Process template
replace_template_placeholders INPUT_FILE OUTPUT_FILE [OPTIONS] VAR=VALUE ...
```

#### Synopsis

```
replace_template_placeholders TEMPLATE OUTPUT [--extensions-dir DIR] VARIABLE=VALUE ...
```

#### Parameters

- `INPUT` - Input template file path
- `OUTPUT` - Output file path
- `--extensions-dir DIR` - Optional extensions directory
- `VAR=VALUE` - Variable assignments (can be multiple)
- `VAR=@file` - Variable from file content

#### Examples

```bash
# Simple processing
replace_template_placeholders \
    template.tpl \
    output.h \
    "MODULE=dap_core" \
    "VERSION=1.0"

# With file-based data
echo "type1|type2|type3" > types.txt
replace_template_placeholders \
    template.tpl \
    output.h \
    "TYPES=@types.txt"

# With extensions
replace_template_placeholders \
    template.tpl \
    output.h \
    --extensions-dir "../mocks/lib/dap_tpl" \
    "TYPE=dap_list_t*"
```

#### Environment Variables

- `SCRIPTS_DIR` - Path to dap_tpl directory (auto-detected)
- `TEMPLATES_DIR` - Path to templates directory (auto-detected)
- `AWKPATH` - Search path for @include directives

### dap_tpl_lib.sh

Additional library functions for advanced use cases.

**Location:** `dap_tpl/dap_tpl_lib.sh`

**Note:** This library is optional and provides specialized functions. Most users only need `dap_tpl.sh`.

#### Available Functions

The library provides helper functions for:
- Template validation
- Batch processing
- Custom error handling

Consult the source file for available functions and their signatures.

---

## API Reference

### Core Functions

#### replace_template_placeholders

Main function for template processing.

**Signature:**
```bash
replace_template_placeholders TEMPLATE OUTPUT [--extensions-dir DIR] VAR=VALUE ...
```

**Returns:**
- 0 on success
- 1 on error

**Error Handling:**
- Template file not found
- Output file write error
- Template syntax error
- Missing required variables

#### Internal Functions

These are used internally and not meant for direct use:

- `tokenize()` - Parse template into AST
- `evaluate_tree()` - Evaluate AST with variables
- `render_tree()` - Convert AST to text

---

## Advanced Topics

### Creating Custom Constructs

See README.md section "Adding New Constructs".

### Extension System

Place custom constructs in a separate directory and use:
```bash
--extensions-dir path/to/extensions
```

Each extension should contain `definition.awk`, `tokenizer.awk`, and `evaluator.awk` files (as needed).

### Performance Optimization

- Engine compilation is cached in `/tmp`
- Reuse compiled engine for multiple templates
- Use file-based data (`@file`) for large datasets

### Debugging

Enable debug output:
```bash
# Add to template
{{! Debug: VAR={{VAR}} }}
```

Check intermediate files:
```bash
# AWK sections create temp files in /tmp
ls -la /tmp/awk_script_*
```

### Best Practices

1. Use meaningful variable names
2. Add comments for complex logic
3. Use macros for repeated code
4. Split large templates with includes
5. Test templates with sample data
6. Use `--extensions-dir` for custom functions

### Common Pitfalls

#### Incorrect keyword_len

```awk
// WRONG
tokenize_simple_construct(marker_text, "include", 7, ...)

// CORRECT  
tokenize_simple_construct(marker_text, "include", 8, ...)
// keyword_len = length("#include") = 8
```

#### Missing Quotes in Conditions

```
{{! WRONG }}
{{#if TYPE == dap_list_t*}}

{{! CORRECT }}
{{#if TYPE == 'dap_list_t*'}}
```

#### Unescaped Pipes in Data

```bash
# WRONG
"LIST=item|with|pipe char|another"

# CORRECT - use newline instead
LIST="item with pipe|char
another item"
```

---

## Construct Index

### if

Conditional execution.

**Syntax:**
```
{{#if CONDITION}}...{{#elif CONDITION}}...{{else}}...{{/if}}
```

**Example:**
```
{{#if COUNT > 0}}
Items: {{COUNT}}
{{/if}}
```

### for

Loop iteration.

**Syntax:**
```
{{#for VAR in LIST}}...{{/for}}
```

**Example:**
```
{{#for item in ITEMS}}
Item: {{item}}
{{/for}}
```

### set

Variable assignment.

**Syntax:**
```
{{#set VAR=value}}
```

**Example:**
```
{{#set TEMP=hello}}
{{TEMP}}
```

### macro

Define reusable template fragment.

**Syntax:**
```
{{#macro NAME}}...{{/macro}}
```

**Example:**
```
{{#macro GREETING}}
Hello, {{ARG0}}!
{{/macro}}
```

### call

Invoke macro.

**Syntax:**
```
{{#call NAME|arg1|arg2}}
```

**Example:**
```
{{#call GREETING|World}}
```

### include

Include template or file.

**Syntax:**
```
{{#include "filename"}}
```

**Example:**
```
{{#include "header.tpl"}}
{{#include "types.h"}}
```

### comment

Add comments (removed from output).

**Syntax:**
```
{{! single line }}
{{!-- multi
line --}}
```

**Example:**
```
{{! This won't appear }}
Code here
{{!--
This is a
multi-line comment
--}}
```

### AWK

Execute AWK code.

**Syntax:**
```
{{AWK:}}
AWK code
{{/AWK}}
```

**Example:**
```
{{AWK:}}
BEGIN {
    for (i=0; i<5; i++)
        print "#define ITEM_" i " " i
}
{{/AWK}}
```

### SH

Execute shell commands.

**Syntax:**
```
{{SH:}}
shell commands
{{/SH}}
```

**Example:**
```
{{SH:}}
echo "// Date: $(date)"
{{/SH}}
```

---

## Appendices

### Appendix A: Variable Function Reference

| Function | Syntax | Description | Example |
|----------|--------|-------------|---------|
| split | `{{VAR\|split\|delim}}` | Split by delimiter | `{{LIST\|split\|pipe}}` |
| part | `{{VAR\|part\|N}}` | Get Nth part | `{{LIST\|part\|0}}` |
| trim | `{{VAR\|trim}}` | Trim whitespace | `{{NAME\|trim}}` |
| contains | `{{VAR\|contains\|text}}` | Check substring | `{{TYPE\|contains\|*}}` |
| replace | `{{VAR\|replace\|pat\|rep}}` | Replace pattern | `{{TEXT\|replace\|old\|new}}` |
| ne | `{{VAR\|ne\|val}}` | Not equal | `{{COUNT\|ne\|0}}` |
| in_list | `{{VAR\|in_list}}` | In list check | `{{ITEM\|in_list}}` |
| remove_suffix | `{{VAR\|remove_suffix\|suf}}` | Remove suffix | `{{TYPE\|remove_suffix\|_t}}` |

**Note:** Additional functions (e.g., `normalize_name`, `escape_name`, `sanitize_name`) may be available through extensions.

### Appendix B: Operator Precedence

1. Logical NOT (`!`)
2. Comparison (`==`, `!=`, `>`, `>=`, `<`, `<=`)
3. Special (`contains`, `matches`, `in`)
4. Logical AND (`&&`)
5. Logical OR (`||`)

### Appendix C: Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "Macro 'X' is not defined" | Macro called before definition | Define macro before calling it |
| "Compiled engine not found" | Missing DAP_TPL_ENGINE_PATH | Set environment variable or rebuild |
| "Template file not found" | Incorrect file path | Verify file exists and path is correct |
| "Maximum include depth exceeded" | Too many nested includes (>10) | Reduce include nesting depth |
| "Syntax error: Unterminated quoted string" | Variable escaping issue | Check special characters in variables |

### Appendix D: Testing Your Templates

```bash
# Run template with test data
cd dap_tpl
source dap_tpl.sh

replace_template_placeholders \
    your_template.tpl \
    /tmp/output.txt \
    "VAR1=test1" \
    "VAR2=test2"

# Check output
cat /tmp/output.txt

# Verify result
diff expected_output.txt /tmp/output.txt

# Run system tests (from dap-sdk/tests/)
cd ../../tests
./run.sh test-framework     # Run all test-framework tests
./run.sh unit               # Run unit tests only
./run.sh integration        # Run integration tests only

# Or via CTest (from dap-sdk/build/)
cd ../build
ctest -L test-framework --output-on-failure
```

---

---

## Quick Reference Card

### Variables
```
{{VAR}}              Simple variable
{{VAR|func|arg}}     Variable with function
```

### Control Flow
```
{{#if COND}}...{{/if}}           Conditional
{{#elif COND}}...{{/elif}}       Else-if
{{#for item in LIST}}...{{/for}} Loop
{{#set VAR=val}}                 Assignment
```

### Reusability
```
{{#macro NAME}}...{{/macro}}     Define macro
{{#call NAME|arg}}               Call macro
{{#include "file"}}              Include template
```

### Comments
```
{{! comment }}                   Single-line
{{!-- comment --}}               Multi-line
```

---

**Version:** 2.0  
**Last Updated:** 2025-11-13  
**Author:** DAP SDK Team

