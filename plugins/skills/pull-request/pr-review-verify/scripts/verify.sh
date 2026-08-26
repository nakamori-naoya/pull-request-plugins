#!/usr/bin/env bash
set -uo pipefail
repo=""; commands_file=""
while [ $# -gt 0 ]; do case "$1" in --repo) repo="${2:-}"; shift 2;; --commands-file) commands_file="${2:-}"; shift 2;; *) echo "[error] 未知の引数: $1" >&2; exit 2;; esac; done
[ -d "$repo" ] && [ -f "$commands_file" ] || { echo "[error] --repoと--commands-fileが必要" >&2; exit 2; }
jq -e 'type=="array" and length>0 and all(.[]; type=="string" and length>0)' "$commands_file" >/dev/null || { echo "[error] commands schemaが不正" >&2; exit 2; }
count=$(jq length "$commands_file"); i=0
while [ "$i" -lt "$count" ]; do command=$(jq -r --argjson i "$i" '.[$i]' "$commands_file"); echo "[verify] $command" >&2; (cd "$repo" && bash -lc "$command") || exit 3; i=$((i+1)); done
printf '{"status":"passed","commands":%s}\n' "$count"
