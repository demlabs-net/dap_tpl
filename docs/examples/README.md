# DAP TPL Examples

This directory contains example templates demonstrating all features of the DAP TPL system.

## Examples

1. **01_variables.tpl** - Variables, split, part, trim, contains, ne
2. **02_conditionals.tpl** - if/elif/else, comparisons, logical operators
3. **03_loops.tpl** - for loops, nested loops, loop with conditionals
4. **04_macros.tpl** - Macro definition and calls with parameters
5. **05_includes.tpl** - Template and file includes
6. **06_complex.tpl** - Combined features in real-world scenario
7. **07_awk_sections.tpl** - Embedded AWK and shell code

## Running Examples

```bash
cd dap_tpl
source dap_tpl.sh

# Process an example
replace_template_placeholders \
    docs/examples/01_variables.tpl \
    /tmp/output.txt \
    "MODULE_NAME=test_module"

# With mocking extensions
replace_template_placeholders \
    docs/examples/06_complex.tpl \
    /tmp/output.h \
    --extensions-dir "../mocks/lib/dap_tpl" \
    "MODULE=dap_crypto" \
    "MOCK_LIST=init|int|void
cleanup|void|void
process|char*|const char* data"
```

## Learning Path

1. Start with **01_variables.tpl** - Basic syntax
2. Then **02_conditionals.tpl** - Control flow
3. Then **03_loops.tpl** - Iteration
4. Then **04_macros.tpl** - Reusability
5. Then **05_includes.tpl** - Modularity
6. Finally **06_complex.tpl** - Real-world usage

## See Also

- **../DAP_TPL_GUIDE.md** - Complete reference and tutorial
- **../../tests/integration/** - Integration test examples

