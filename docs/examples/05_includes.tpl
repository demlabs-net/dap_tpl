// Example 5: Includes
// Demonstrates: template includes, recursive processing, file includes
// See: docs/DAP_TPL_GUIDE.md#includes

// Include a template (will be processed recursively)
{{#include "header_common.tpl"}}

// Include with variables
{{#set MODULE=test_module}}
{{#include "module_header.tpl"}}

// Include regular files (included as-is)
{{#include "standard_defines.h"}}

// Conditional includes
{{#if ENABLE_CUSTOM_MOCKS}}
{{#include "custom_mocks.h"}}
{{/if}}

// Loop with includes
{{#set MODULES=core|utils|network}}
{{#for module in MODULES}}
{{#set MODULE={{module}}}}
{{#include "module_stub.tpl"}}
{{/for}}

