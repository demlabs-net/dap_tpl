# DAP Template Processing System (dap_tpl)

Template processing system for DAP SDK test framework with modular architecture and extensible design.

**Languages:** [English](README.md) | [Русский](README.ru.md)

## Features

- Modular plugin-based construct system
- Advanced condition parsing with logical operators
- Macro system with parameters
- Recursive template inclusion
- Variable functions and transformations
- Embedded AWK and shell script execution
- Complete test coverage

## Quick Start

### Basic Usage

```bash
# Source the library
source dap_tpl/dap_tpl.sh

# Process a template
replace_template_placeholders \
    "input.tpl" \
    "output.h" \
    "VAR1=value1" \
    "VAR2=value2"

# With mocking extensions
replace_template_placeholders \
    "input.tpl" \
    "output.h" \
    --extensions-dir "../mocks/lib/dap_tpl" \
    "TYPE=dap_list_t*"
```

### Template Syntax

```
{{VAR}}                                  - Variable substitution
{{VAR|split|pipe}}                       - Variable with function
{{#if VAR}}...{{else}}...{{/if}}        - Conditional
{{#if VAR == value}}...{{/if}}          - Comparison
{{#if VAR > 5}}...{{/if}}               - Numeric comparison
{{#if VAR contains 'text'}}...{{/if}}   - Substring check
{{#if VAR1 && VAR2}}...{{/if}}          - Logical AND
{{#if VAR1 || VAR2}}...{{/if}}          - Logical OR
{{#if !VAR}}...{{/if}}                  - Logical NOT
{{#elif VAR == 2}}...{{/elif}}          - Elif support
{{#for item in LIST}}...{{/for}}        - Loop
{{#set VAR=value}}...{{/set}}           - Variable assignment
{{#macro NAME}}...{{/macro}}            - Macro definition
{{#call NAME|arg1|arg2}}                - Macro call
{{#include "file.tpl"}}                 - Include template
{{! comment }}                          - Single-line comment
{{!-- multi-line comment --}}           - Multi-line comment
```

## Architecture

### Core Modules

- **token_tree.awk** - AST management
- **variable_context.awk** - Stack-based variable scoping
- **macro_store.awk** - Macro storage and expansion
- **construct_registry.awk** - Plugin registration system
- **tokenizer_core.awk** - Universal tokenizer with dispatch
- **evaluator_core.awk** - Universal evaluator with dispatch
- **renderer.awk** - AST to text conversion
- **condition_parser.awk** - Condition parsing

### Constructs

Each construct is a self-contained plugin:
- **if** - Conditional blocks with elif/else
- **for** - Loop iteration
- **set** - Variable assignment
- **var** - Variable substitution
- **macro** - Reusable fragments
- **call** - Macro invocation
- **include** - Template inclusion
- **comment** - Comments
- **awk_section** - AWK code execution
- **sh_section** - Shell script execution

## Building

```bash
# Build engine
./utils/build_engine.sh

# Build with extensions
./utils/build_engine.sh ../mocks/lib/dap_tpl

# Capture engine path
ENGINE_OUTPUT=$(./utils/build_engine.sh 2>&1)
COMPILED_ENGINE=$(echo "$ENGINE_OUTPUT" | grep "^ENGINE_PATH=" | cut -d'=' -f2-)
```

## Testing

```bash
cd tests
./run.sh              # All tests (unit + integration)
./run.sh unit         # Unit tests only
./run.sh integration  # Integration tests only
```

Test results: 41 tests (27 unit + 10 integration + 4 mocking)

## Documentation

- **[docs/DAP_TPL_GUIDE.md](docs/DAP_TPL_GUIDE.md)** - Complete guide with tutorial, reference and cookbook
- **[docs/examples/](docs/examples/)** - 7 example templates with learning path

## Variable Functions

Core functions:
- `split` - Split value: `{{VAR|split|pipe}}`
- `part` - Get part: `{{VAR|part|0}}`
- `contains` - Check substring: `{{VAR|contains|text}}`
- `ne` - Not equal: `{{VAR|ne|value}}`
- `in_list` - Check in list: `{{VAR|in_list}}`
- `remove_suffix` - Remove suffix: `{{VAR|remove_suffix|_t}}`
- `trim` - Trim whitespace: `{{VAR|trim}}`

Mocking functions:
- `normalize_name` - Normalize identifier: `{{TYPE|normalize_name}}`
- `escape_name` - Escape chars: `{{TYPE|escape_name}}`
- `escape_char` - Escape specific: `{{TYPE|escape_char|*|_PTR}}`
- `sanitize_name` - Clean name: `{{TYPE|sanitize_name}}`

## Adding New Constructs

1. Create construct directory: `constructs/my_construct/`
2. Add required files:
   - `definition.awk` - Register construct in registry
   - `tokenizer.awk` - Parse construct syntax
   - `evaluator.awk` - Evaluate construct logic
3. Rebuild engine: `./utils/build_engine.sh`

The build system automatically discovers and includes new constructs.

See [docs/DAP_TPL_GUIDE.md](docs/DAP_TPL_GUIDE.md#adding-new-constructs) for detailed guide.

## Requirements

- GNU AWK 4.0+
- Bash 3.0+
- GNU coreutils

## License

Part of DAP SDK - Cellframe Network
