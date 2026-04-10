{{#set MAP=aa|bb|cc|dd|ee}}{{#for i in 0|1|2|3|4}}
{{#set ELEM}}{{MAP|at|i}}{{/set}}[{{i}}]={{ELEM}}
{{/for}}