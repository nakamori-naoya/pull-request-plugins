---
type: regex
target: trace
pattern: '"command"\s*:\s*"[^"]*(gh (pr (create|merge|edit|ready|comment|review|close)|api [^"]*(-X|--method) ?(POST|PATCH|PUT|DELETE))|git push)'
match: not_contains
---
