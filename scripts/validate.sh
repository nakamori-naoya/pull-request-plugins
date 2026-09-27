#!/usr/bin/env bash
# pull-request の repository 検査。配置と manifest は harness-tools の validate-plugin-repository.py が判定する。
# ここで足すのは shell の構文だけである。競合解消と review の採否の判断が十分かは、読んで評価する。
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# 保守toolの実装元は兄弟checkoutの harness-tools。無ければ止まる（fixtureで代用しない）。
TOOLS="$ROOT/../harness-tools/tools"
[ -d "$TOOLS" ] || { echo "[error] 兄弟 checkout harness-tools が無い: $TOOLS" >&2; exit 2; }
failed=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; failed=1; }

python3 "$TOOLS/validate-plugin-repository.py" "$ROOT" && pass "package 構造（harness-tools）" || fail "package 構造（harness-tools）"
python3 "$TOOLS/test-hardening.py" --repository "$ROOT" && pass "保守toolの回帰検査" || fail "保守toolの回帰検査"
while IFS= read -r script; do bash -n "$script" || fail "shell 構文: $script"; done < <(find "$ROOT/scripts" -name '*.sh' -type f)

if [ "$failed" -eq 0 ]; then echo 'Validation: passed'; else echo 'Validation: failed'; fi
[ "$failed" -eq 0 ]
