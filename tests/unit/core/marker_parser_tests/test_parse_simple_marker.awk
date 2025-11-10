@include "core/marker_parser.awk"
BEGIN {
    marker_text = "{{VAR}}"
    var_expr = parse_marker(marker_text)
    if (var_expr != "VAR") {
        print "FAIL: Expected 'VAR', got '" var_expr "'"
        exit 1
    }
    print "PASS"
}

