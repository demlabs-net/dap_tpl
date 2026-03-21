{{#set DATA_0=first}}{{#set DATA_1=second}}{{#set DATA_2=third}}{{#for i in 0|1|2}}
{{#set ITEM}}{{i|resolve|DATA_}}{{/set}}{{i}}: {{ITEM}}
{{/for}}