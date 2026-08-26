#!/usr/bin/env bash
set -uo pipefail
action="${1:-}"; [ -n "$action" ] || { echo "usage: publish.sh commit|push ..." >&2; exit 2; }; shift
cfg=""; repo=""; paths=""; approved=0
while [ $# -gt 0 ]; do
  case "$1" in
    --config) cfg="${2:-}"; shift 2 ;;
    --repo) repo="${2:-}"; shift 2 ;;
    --paths-file) paths="${2:-}"; shift 2 ;;
    --approved) approved=1; shift ;;
    *) echo "[error] 未知の引数: $1" >&2; exit 2 ;;
  esac
done
[ -f "$cfg" ] && [ -d "$repo" ] || { echo "[error] --configと--repoが必要" >&2; exit 2; }
read_cfg() { yq -er ".playbook.$1" "$cfg"; }
case "$action" in
  commit)
    [ "$(read_cfg permissions.commit)" = true ] || { echo '{"status":"commit_denied"}'; exit 3; }
    if [ "$(read_cfg gates.before_commit)" = true ] && [ "$approved" != 1 ]; then echo '{"status":"waiting_for_human","gate":"before_commit"}'; exit 3; fi
    [ -f "$paths" ] && [ -s "$paths" ] || { echo "[error] 空でない--paths-fileが必要" >&2; exit 2; }
    while IFS= read -r path; do
      case "$path" in ''|/*|../*|*/../*|*'/..') echo "[error] repository相対pathではない: $path" >&2; exit 2 ;; esac
      git -C "$repo" add -- "$path" || exit 2
    done < "$paths"
    git -C "$repo" diff --cached --quiet && { echo "[error] stage対象が無い" >&2; exit 2; }
    message=$(read_cfg git.commit_message)
    git -C "$repo" commit -m "$message" || exit 2
    printf '{"status":"committed","commit":"%s"}\n' "$(git -C "$repo" rev-parse HEAD)"
    ;;
  push)
    [ "$(read_cfg permissions.push)" = true ] || { echo '{"status":"push_denied"}'; exit 3; }
    if [ "$(read_cfg gates.before_push)" = true ] && [ "$approved" != 1 ]; then echo '{"status":"waiting_for_human","gate":"before_push"}'; exit 3; fi
    branch=$(git -C "$repo" branch --show-current)
    case "$branch" in ''|main|master) echo "[error] protected branchはpushしない: $branch" >&2; exit 2 ;; esac
    remote=$(read_cfg git.remote)
    git -C "$repo" push -u "$remote" "$branch" || exit 2
    printf '{"status":"pushed","remote":"%s","branch":"%s"}\n' "$remote" "$branch"
    ;;
  *) echo "[error] actionはcommitまたはpush" >&2; exit 2 ;;
esac
