#!/usr/bin/env bash
# pull-request の repository 検査。判定するのは、配置と manifest の一致、公開入口の SKILL の name、
# symlink の有無だけである。競合解消と review の採否の判断が十分かは、読んで評価する。
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# 保守toolの実装元は兄弟checkoutの harness-tools。無ければ止まる（fixtureで代用しない）。
TOOLS="$ROOT/../harness-tools/tools"
[ -d "$TOOLS" ] || { echo "[error] 兄弟 checkout harness-tools が無い: $TOOLS" >&2; exit 2; }
failed=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; failed=1; }

PACKAGE="$ROOT/plugins/pull-request"
ENTRIES=(open-pull-request resolve-pr-conflicts respond-to-pr-review)

python3 "$TOOLS/validate-plugin-repository.py" "$ROOT" && pass "package 構造（harness-tools）" || fail "package 構造（harness-tools）"
python3 "$TOOLS/test-hardening.py" --repository "$ROOT" && pass "保守toolの回帰検査" || fail "保守toolの回帰検査"

jq -e '.skills==["./skills/open-pull-request","./skills/resolve-pr-conflicts","./skills/respond-to-pr-review"]
       and .metadata.harness=={"marketplace":"pull-request","contractVersion":1}' "$PACKAGE/.codex-plugin/plugin.json" >/dev/null \
  && pass "公開入口3つ、playbooks / implements 無し" || fail "manifest の公開宣言"
[ "$(find "$ROOT/plugins" -name SKILL.md -type f | wc -l | tr -d ' ')" -eq 3 ] && pass "SKILL.md は公開入口の3本だけ" || fail "SKILL.md の本数"
[ "$(find "$ROOT/plugins" -type l | wc -l | tr -d ' ')" -eq 0 ] && pass "配布物に symlink なし" || fail "配布物に symlink がある"
for entry in "${ENTRIES[@]}"; do
  name=$(awk 'NR==1 { if ($0 != "---") exit 2; next } $0=="---" { exit } { print }' "$PACKAGE/skills/$entry/SKILL.md" | yq -r '.name')
  [ "$name" = "$entry" ] && pass "$entry: SKILL の name" || fail "$entry: SKILL の name = $name"
done
while IFS= read -r script; do bash -n "$script" || fail "shell 構文: $script"; done < <(find "$ROOT/scripts" -name '*.sh' -type f)

if [ "$failed" -eq 0 ]; then echo 'Validation: passed'; else echo 'Validation: failed'; fi
[ "$failed" -eq 0 ]
