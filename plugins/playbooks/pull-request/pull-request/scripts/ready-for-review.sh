#!/usr/bin/env bash
# Scenario: 内部レビュー済みのPRだけを Agent Work Policy の契約でレビュー受付へ遷移する
set -euo pipefail

policy_root=""
repo="$(pwd)"
pr=""
internal_review_complete=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --policy-root)
      [ "$#" -ge 2 ] || { echo '{"status":"invalid","reason":"policy_root_missing"}'; exit 2; }
      policy_root="$2"
      shift 2
      ;;
    --policy-root=*)
      policy_root="${1#--policy-root=}"
      [ -n "$policy_root" ] || { echo '{"status":"invalid","reason":"policy_root_missing"}'; exit 2; }
      shift
      ;;
    --repo)
      [ "$#" -ge 2 ] || { echo '{"status":"invalid","reason":"repo_missing"}'; exit 2; }
      repo="$2"
      shift 2
      ;;
    --repo=*)
      repo="${1#--repo=}"
      [ -n "$repo" ] || { echo '{"status":"invalid","reason":"repo_missing"}'; exit 2; }
      shift
      ;;
    --pr)
      [ "$#" -ge 2 ] || { echo '{"status":"invalid","reason":"pr_missing"}'; exit 2; }
      pr="$2"
      shift 2
      ;;
    --pr=*)
      pr="${1#--pr=}"
      [ -n "$pr" ] || { echo '{"status":"invalid","reason":"pr_missing"}'; exit 2; }
      shift
      ;;
    --internal-review-complete)
      internal_review_complete=true
      shift
      ;;
    *)
      echo '{"status":"invalid","reason":"unknown_argument"}'
      exit 2
      ;;
  esac
done

[ -n "$policy_root" ] && [ -d "$policy_root" ] || { echo '{"status":"invalid","reason":"policy_root_missing"}'; exit 2; }
[ -x "$policy_root/scripts/prepare.sh" ] && [ -f "$policy_root/scripts/control.py" ] || { echo '{"status":"invalid","reason":"policy_capability_missing"}'; exit 2; }
[ -n "$pr" ] || { echo '{"status":"invalid","reason":"pr_missing"}'; exit 2; }
[ "$internal_review_complete" = true ] || { echo '{"status":"internal_review_incomplete"}'; exit 3; }

# 依存先が 0.1.6 の ready-for-review 契約を提供しない場合は、公開操作を行わず停止する。
python3 "$policy_root/scripts/control.py" --help 2>&1 | grep -q 'ready-for-review' || {
  echo '{"status":"invalid","reason":"policy_capability_missing"}'
  exit 2
}

policy_cfg=$(bash "$policy_root/scripts/prepare.sh" "$repo") || exit 2
[ -n "$policy_cfg" ] || { echo '{"status":"invalid","reason":"policy_config_missing"}'; exit 2; }
trap 'rm -f "$policy_cfg"' EXIT

if result=$(python3 "$policy_root/scripts/control.py" ready-for-review --config "$policy_cfg" --repo "$repo" --pr "$pr"); then
  status=0
else
  status=$?
fi
printf '%s\n' "$result"
[ "$status" -eq 0 ] || exit "$status"
jq -e '.status == "ready" and (.changed | type == "boolean")' >/dev/null <<<"$result" || exit 2
