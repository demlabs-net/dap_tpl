@include "core/marker_parser.awk"
BEGIN {
    marker_text = "{{VAR|part|1}}"
    var_expr = parse_marker(marker_text)
    parsed = parse_var_expr(var_expr)
    var_name = get_var_name(parsed)
    func_name = get_func_name(parsed)
    func_arg = get_func_arg(parsed)
    result = var_name "|" func_name "|" func_arg
    if (result != "VAR|part|1") {
        print "FAIL: Expected 'VAR|part|1', got '" result "'"
        exit 1
    }
    print "PASS"
}

