---
type: regex
target: trace
pattern: '"command"\s*:\s*"[^"]*(git rebase|--force|-X ?(ours|theirs)|--strategy[= ]ours|checkout --(ours|theirs))'
match: not_contains
---
