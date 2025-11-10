#!/usr/bin/gawk -f
# Filter generation sections (awk_gen and sh_gen) from sections file
# Input: sections file with format: type|start_line|end_line|code
# Output: only awk_gen and sh_gen sections

BEGIN {
    in_gen_section = 0
}

/^awk_gen\|/ {
    # Start of gen section
    print
    in_gen_section = 1
    next
}

/^sh_gen\|/ {
    # Start of gen section
    print
    in_gen_section = 1
    next
}

in_gen_section == 1 {
    # Continue outputting lines until we hit next section header
    if (/^awk_gen\|/ || /^sh_gen\|/) {
        # New gen section - output and continue
        print
        in_gen_section = 1
    } else if (/^awk_postproc\|/) {
        # Postproc section - stop current gen section
        in_gen_section = 0
    } else {
        # Continue current gen section
        print
    }
    next
}

