{{#set LIST=aa|bb|cc|dd|ee}}
{{#set X=3}}
math: {{X|math|$+10}}
at_literal: {{LIST|at|2}}
at_var: {{LIST|at|X}}
at_expr: {{LIST|at|X-2}}
math_mod: {{X|math|($+1)%5}}
