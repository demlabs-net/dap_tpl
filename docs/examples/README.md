# DAP TPL Examples

This directory contains example templates demonstrating all features of the DAP TPL system.

**See also:** [Learning Path](#learning-path) | [Parent Documentation](../DAP_TPL_GUIDE.md)

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

Follow these examples in order for best learning experience:

1. **01_variables.tpl** - Variables, split, part, trim, contains, ne
   - Learn basic variable substitution and transformation functions
   
2. **02_conditionals.tpl** - if/elif/else, comparisons, logical operators
   - Master conditional logic and decision-making
   
3. **03_loops.tpl** - for loops, nested loops, conditional loops
   - Understand iteration and data processing
   
4. **04_macros.tpl** - Macro definition and calls with parameters
   - Create reusable template fragments
   
5. **05_includes.tpl** - Template and file includes
   - Build modular template systems
   
6. **06_complex.tpl** - Combined features in production scenario
   - See how all features work together
   
7. **07_awk_sections.tpl** - Embedded AWK and shell code
   - Advanced code generation techniques

**Estimated time:** 30-60 minutes to complete all examples

## See Also

- **../DAP_TPL_GUIDE.md** - Complete reference and tutorial
- **../../tests/integration/** - Integration test examples

