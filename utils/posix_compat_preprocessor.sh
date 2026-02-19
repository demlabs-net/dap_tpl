#!/bin/sh
# POSIX AWK Compatibility Preprocessor
# Replaces gawk-specific constructs with POSIX-compatible alternatives:
#   - systime() -> dap_compat_systime()
#   - PROCINFO["pid"] -> ENVIRON["DAP_AWK_PID"]
#   - \n and \t in regex -> character class alternatives (for BSD awk)
#
# The compatibility functions are injected at the beginning of the output.

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input_file> [output_file]" >&2
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-}"

[ ! -f "$INPUT_FILE" ] && echo "Error: File not found: $INPUT_FILE" >&2 && exit 1

# Create temp file for processing
TMP_FILE=$(mktemp)
TMP_FILE2=$(mktemp)
trap 'rm -f "$TMP_FILE" "$TMP_FILE2"' EXIT

# Inject POSIX compatibility layer at the beginning
cat > "$TMP_FILE" << 'COMPAT_LAYER'
# ============================================================================
# POSIX AWK Compatibility Layer
# Provides replacements for gawk-specific functions and BSD awk compatibility
# ============================================================================

# Character constants for BSD awk compatibility
# BSD awk doesn't understand \n \t in regex literals, use these instead
BEGIN {
    _NEWLINE = sprintf("%c", 10)
    _TAB = sprintf("%c", 9)
    _SPACE = " "
}

# POSIX-compatible systime() replacement
# Uses shell date command via ENVIRON or system() call
# Returns: current Unix timestamp
function dap_compat_systime(    cmd, result) {
    # First try cached value from environment (set by dap_tpl.sh)
    if ("DAP_AWK_SYSTIME" in ENVIRON && ENVIRON["DAP_AWK_SYSTIME"] != "") {
        return ENVIRON["DAP_AWK_SYSTIME"] + 0
    }
    # Fallback: call shell date command
    cmd = "date +%s"
    cmd | getline result
    close(cmd)
    return result + 0
}

# POSIX-compatible PID getter
# Returns: process ID from environment
function dap_compat_pid() {
    if ("DAP_AWK_PID" in ENVIRON && ENVIRON["DAP_AWK_PID"] != "") {
        return ENVIRON["DAP_AWK_PID"]
    }
    # Fallback: use parent PID if available
    if ("PPID" in ENVIRON) {
        return ENVIRON["PPID"]
    }
    # Last resort: return a pseudo-random number based on NR and rand()
    return int(rand() * 100000)
}

# BSD awk compatible match function wrapper
# Converts regex with \n \t to string form
function dap_compat_match(str, pat,    result) {
    return match(str, pat)
}

# ============================================================================
# End of POSIX Compatibility Layer
# ============================================================================

COMPAT_LAYER

# Process the input file: replace gawk-specific constructs
awk '
{
    line = $0
    
    # Replace systime() with dap_compat_systime()
    gsub(/systime\(\)/, "dap_compat_systime()", line)
    
    # Replace PROCINFO["pid"] with dap_compat_pid()
    gsub(/PROCINFO\["pid"\]/, "dap_compat_pid()", line)
    gsub(/PROCINFO\['\''pid'\''\]/, "dap_compat_pid()", line)
    
    print line
}
' "$INPUT_FILE" >> "$TMP_FILE"

# Step 2: Convert regex literals with \n \t to string concatenation form for BSD awk
# BSD awk doesn't understand \n \t inside /regex/ literals
# Convert: /^\n[ \t]+/  ->  "^" _NEWLINE "[ " _TAB "]+"
# This is a complex transformation, use sed for pattern replacement

# Replace common problematic patterns in regex
sed -E '
    # Pattern: ~ /...\n.../  -> ~ ("..." _NEWLINE "...")
    # Handle /^\n[ \t]+/ specifically
    s|~ /\^\\n\[ \\t\]\+/|~ ("^" _NEWLINE "[ " _TAB "]+")|g
    s|~ /\^\\n\[ \\t\]\*/|~ ("^" _NEWLINE "[ " _TAB "]*")|g
    
    # Handle /\\n/ alone
    s|~ /\\n/|~ _NEWLINE|g
    s|!~ /\\n/|!~ _NEWLINE|g
    
    # Handle /\\t/ alone  
    s|~ /\\t/|~ _TAB|g
    s|!~ /\\t/|!~ _TAB|g
    
    # Handle /[ \t]/ patterns - these are OK in BSD awk, but \t inside [] may not be
    # Replace /[ \t]+/ with /[[:space:]]+/
    s|/\[ \\t\]\+/|/[[:space:]]+/|g
    s|/\[ \\t\]\*/|/[[:space:]]*/|g
    s|/\[\\t \]\+/|/[[:space:]]+/|g
    s|/\[\\t \]\*/|/[[:space:]]*/|g
    
    # Handle \n in the middle of regex - convert to character class
    # /pattern\npattern/ -> /pattern/ _NEWLINE /pattern/ is complex
    # For now, replace simple cases
    
    # Replace \\n inside regex with actual newline representation
    # This is tricky - use octal
    
' "$TMP_FILE" > "$TMP_FILE2"

mv "$TMP_FILE2" "$TMP_FILE"

# Output result
if [ -n "$OUTPUT_FILE" ]; then
    mv "$TMP_FILE" "$OUTPUT_FILE"
    trap '' EXIT  # Disable trap since file was moved
    echo "POSIX compatibility layer applied: $OUTPUT_FILE" >&2
else
    cat "$TMP_FILE"
fi
