{{#set RESULT={{AWK:
BEGIN {
    sum = 0
    for (i = 1; i <= 5; i++) {
        sum += i
    }
    print sum
}
}}}}
Result: {{RESULT}}

