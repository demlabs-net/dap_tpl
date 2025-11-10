# Library function for parsing template constructs
# Can be included via @include and called as function
# Input: array of lines (content_lines[1..n_lines])
# Output: constructs array with parsed constructs
# Returns: number of constructs found

# Function to parse constructs from array of lines
# Uses parse_template_constructs.awk via temporary file
# Returns number of constructs found
function parse_constructs_from_array(content_lines, n_lines, constructs_out,    temp_file, i, line, count, constructs_file, scripts_dir, cmd, field1_end, field2_end, field3_end, field4_end) {
    scripts_dir = ENVIRON["SCRIPTS_DIR"]
    if (scripts_dir == "") scripts_dir = "."
    
    # Write content to temporary file
    temp_file = "/tmp/parse_constructs_" NR "_" rand() ".tpl"
    for (i = 1; i <= n_lines; i++) {
        if (content_lines[i] != "") {
            printf "%s\n", content_lines[i] > temp_file
        } else {
            print "" > temp_file
        }
    }
    close(temp_file)
    
    # Parse using parse_template_constructs.awk via system call
    # Note: parse_template_constructs.awk uses BEGIN/pattern/END blocks,
    # so we need to call it as a separate process
    constructs_file = "/tmp/parsed_constructs_" NR "_" rand() ".txt"
    cmd = "gawk -f \"" scripts_dir "/constructs/parse_template_constructs.awk\" \"" temp_file "\" > \"" constructs_file "\" 2>/dev/null"
    system(cmd)
    
    # Read parsed constructs
    count = 0
    while ((getline line < constructs_file) > 0) {
        count++
        # Parse line: type|start|end|condition|content
        field1_end = index(line, "|")
        if (field1_end == 0) continue
        field2_end = index(substr(line, field1_end + 1), "|")
        if (field2_end == 0) continue
        field2_end = field1_end + field2_end
        field3_end = index(substr(line, field2_end + 1), "|")
        if (field3_end == 0) continue
        field3_end = field2_end + field3_end
        field4_end = index(substr(line, field3_end + 1), "|")
        if (field4_end == 0) continue
        field4_end = field3_end + field4_end
        
        constructs_out[count, "type"] = substr(line, 1, field1_end - 1)
        constructs_out[count, "start"] = substr(line, field1_end + 1, field2_end - field1_end - 1)
        constructs_out[count, "end"] = substr(line, field2_end + 1, field3_end - field2_end - 1)
        constructs_out[count, "condition"] = substr(line, field3_end + 1, field4_end - field3_end - 1)
        constructs_out[count, "content"] = substr(line, field4_end + 1)
        gsub(/\001/, "\n", constructs_out[count, "content"])
    }
    close(constructs_file)
    
    # Cleanup
    system("rm -f " temp_file " " constructs_file)
    
    return count
}

