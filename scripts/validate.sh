#!/usr/bin/env bash
# Scenario: pull-request package が公開入口2つで自己完結し、各入口の決定論的toolが閉じた契約を守り、公開Git操作を自前で実行しない
# 機械検査は宣言と実体の対応、隣接playbook.ymlの契約、設定fileのschema、gate / review-gate / verify の入出力、素の公開操作の不在だけを判定する。
# 競合解消の妥当性、review採否の判断、SKILL本文の判断基準の十分性は意味評価として残す。
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/pull-request-validation.XXXXXX") || exit 2
export TMPDIR="$TMP_ROOT"
export PYTHONDONTWRITEBYTECODE=1
trap 'rm -rf "$TMP_ROOT"' EXIT
failed=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; failed=1; }

PACKAGE="$ROOT/plugins/pull-request"
ENTRY_DIR="$PACKAGE/skills"
ENTRIES=(open-pull-request respond-to-pr-review)

# ── 配置と identity ──────────────────────────────────────────────────────
for market in .claude-plugin/marketplace.json .agents/plugins/marketplace.json; do
  if jq -e '.name=="pull-request" and (.plugins|length)==1 and .plugins[0].name=="pull-request" and .plugins[0].version=="4.0.0"
            and ((.plugins[0].source=="./plugins/pull-request") or (.plugins[0].source=={"source":"local","path":"./plugins/pull-request"}))' "$ROOT/$market" >/dev/null; then
    pass "$market identityとsource"
  else
    fail "$market identityとsource"
  fi
done
claude_identity=$(jq -c '{name,version,skills,harness:.metadata.harness}' "$PACKAGE/.claude-plugin/plugin.json")
codex_identity=$(jq -c '{name,version,skills,harness:.metadata.harness}' "$PACKAGE/.codex-plugin/plugin.json")
[ "$claude_identity" = "$codex_identity" ] && pass "両runtime manifestのidentity一致" || fail "両runtime manifestのidentity一致"
jq -e '.skills==["./skills/open-pull-request","./skills/respond-to-pr-review"]
       and .metadata.harness=={"marketplace":"pull-request","contractVersion":1}' "$PACKAGE/.codex-plugin/plugin.json" >/dev/null \
  && pass "公開入口2つ、playbooks / internalPlugins / implements 無し" || fail "manifestの公開宣言"
manifest_dirs=$(find "$ROOT/plugins" -type d \( -name '.claude-plugin' -o -name '.codex-plugin' \) | sed "s#^$ROOT/##" | sort | tr '\n' ' ')
[ "$manifest_dirs" = "plugins/pull-request/.claude-plugin plugins/pull-request/.codex-plugin " ] \
  && pass "runtime manifest directoryはpackage rootの2つだけ" || fail "runtime manifest directoryが余分または欠落: $manifest_dirs"
skill_dirs=$(find "$ENTRY_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | tr '\n' ' ')
[ "$skill_dirs" = "open-pull-request respond-to-pr-review " ] && pass "skills/直下は公開入口2つだけ" || fail "skills/直下: $skill_dirs"
[ "$(find "$ROOT/plugins" -name SKILL.md -type f | wc -l | tr -d ' ')" -eq 2 ] && pass "SKILL.mdは公開入口の2本だけ（内部skillなし）" || fail "SKILL.mdの本数"
[ "$(find "$ROOT/plugins" -type l | wc -l | tr -d ' ')" -eq 0 ] && pass "配布物にsymlinkなし" || fail "配布物にsymlinkがある"

# ── 公開入口ごとの構造 ─────────────────────────────────────────────────
for entry in "${ENTRIES[@]}"; do
  dir="$ENTRY_DIR/$entry"
  name=$(awk 'NR==1 { if ($0 != "---") exit 2; next } $0=="---" { exit } { print }' "$dir/SKILL.md" | yq -r '.name')
  [ "$name" = "$entry" ] && pass "$entry: SKILL frontmatter name" || fail "$entry: SKILL frontmatter name = $name"
  pb=$(yq -o=json -I=0 '.' "$dir/playbook.yml")
  jq -e --arg n "$entry" '.version==2 and .name==$n
      and (.requires|map(.plugin)|sort)==["agent-work-policy","write-doc"] and all(.requires[]; .marketplace==.plugin)
      and (.inputs|index("document_destination")) and ((.inputs|index("output_target"))|not)
      and ((.steps|map(.id)|unique|length)==(.steps|length))
      and all(.steps[]; ([has("agent_work"),has("script"),has("skill"),has("playbook")]|map(select(.))|length)==1)
      and all(.steps[]|select(has("playbook")); .playbook=="agent-work-policy" or .playbook=="write-doc")
      and all(.steps[]|select(has("playbook")); (has("input")|not) or ((.input|keys)==["document_type"]))
      and ((.. | objects | has("output_to")) | not)
      and ((.|has("permissions"))|not) and ((.|has("gates"))|not) and ((.|has("git"))|not) and ((.|has("verification"))|not) and ((.|has("conflict_report"))|not) and ((.|has("report"))|not)' <<<"$pb" >/dev/null \
    && pass "$entry: playbook.yml identity・外部requires・工程種別・policy値の不在" || fail "$entry: playbook.yml"
  scripts_ok=1
  while IFS= read -r script; do [ -f "$dir/$script" ] || scripts_ok=0; done < <(jq -r '.steps[]|select(has("script")).script' <<<"$pb")
  [ "$scripts_ok" -eq 1 ] && pass "$entry: steps.script は入口内の実在file" || fail "$entry: steps.script の参照先"
  [ -f "$dir/assets/$entry.config.example.yml" ] && pass "$entry: 設定の記入例がある" || fail "$entry: 設定の記入例"
  if rg -n --fixed-strings -e '${.' -e '<!-- BEGIN shared:' -e 'CLAUDE_PLUGIN_ROOT' -e 'BUNDLE_ROOT' "$dir/SKILL.md" "$dir/playbook.yml" "$dir/references" >/dev/null \
    || rg -n 'prepare\.sh|resolve\.sh|run-config\.py|state\.py|work-with-policy|pr-conflict-inspect|pr-conflict-resolve|pr-create|pr-review-assess|pr-review-apply|pr-review-verify' "$dir/SKILL.md" "$dir/references" >/dev/null; then
    fail "$entry: 禁止参照形・旧runtime・旧内部名が残っている"
  else
    pass "$entry: 禁止参照形・旧runtime・旧内部名が無い"
  fi
done
# 公開Git操作の委譲: agent-work-policy へは公開入口名で呼び、消費側がpolicy値を持たない
jq -e '[.steps[]|select(.playbook=="agent-work-policy")|.id]==["workspace","push","create-pull-request","ready-for-review"]' <<<"$(yq -o=json -I=0 '.' "$ENTRY_DIR/open-pull-request/playbook.yml")" >/dev/null \
  && pass "open-pull-request: 公開Git操作4件は agent-work-policy へ委譲" || fail "open-pull-request: 公開Git操作の委譲"
# when が参照する設定値（conflict_report.timing）は read-policy 工程の provides から到達する
jq -e '.steps[0].id=="read-policy" and .steps[0].script=="scripts/config.py" and (.steps[0].provides|index("conflict_report"))
       and all(.steps[]|select(has("when") and (.when|test("conflict_report"))); (.needs|index("conflict_report")))' <<<"$(yq -o=json -I=0 '.' "$ENTRY_DIR/open-pull-request/playbook.yml")" >/dev/null \
  && pass "open-pull-request: 設定値は read-policy の provides から when 参照工程へ到達" || fail "open-pull-request: 設定値の到達性"
OPEN="$ENTRY_DIR/open-pull-request"
open_repo="$TMP_ROOT/open-repo"; mkdir -p "$open_repo/.harness-plugins"
cp "$OPEN/assets/open-pull-request.config.example.yml" "$open_repo/.harness-plugins/open-pull-request.config.yml"
git -C "$open_repo" init -q -b main
cfg_ok=1
python3 "$OPEN/scripts/config.py" --repo "$open_repo" | jq -e '.conflict_report.timing=="before_resolution" and (.verification.commands|type)=="array"' >/dev/null || cfg_ok=0
for edit in '.conflict_report.timing = "later"' '.extra = 1' 'del(.verification)' '.verification.commands = [""]'; do
  cp "$OPEN/assets/open-pull-request.config.example.yml" "$open_repo/.harness-plugins/open-pull-request.config.yml"; yq -i "$edit" "$open_repo/.harness-plugins/open-pull-request.config.yml"
  if python3 "$OPEN/scripts/config.py" --repo "$open_repo" >/dev/null 2>&1; then cfg_ok=0; echo "  受理してはならない設定: $edit"; fi
done
rm "$open_repo/.harness-plugins/open-pull-request.config.yml"
if python3 "$OPEN/scripts/config.py" --repo "$open_repo" > "$TMP_ROOT/open-missing.json" 2>/dev/null; then cfg_ok=0; elif ! jq -e '.reason=="policy_missing"' "$TMP_ROOT/open-missing.json" >/dev/null; then cfg_ok=0; fi
[ "$cfg_ok" -eq 1 ] && pass "config.py: 正例、timing 2値以外・未知key・欠落・空command・policy不在を拒否" || fail "config.py"
jq -e '[.steps[]|select(.playbook=="agent-work-policy")|.id]==["commit","push"] and (.steps[]|select(.id=="assessment-gate")|has("when")) and ((.steps[]|select(.id=="assess")).needs|index("review_import_allowed"))' <<<"$(yq -o=json -I=0 '.' "$ENTRY_DIR/respond-to-pr-review/playbook.yml")" >/dev/null \
  && pass "respond-to-pr-review: commit / push は agent-work-policy へ委譲、accept 0件分岐とreview取込permissionの順序" || fail "respond-to-pr-review: 委譲と分岐"

# 素の公開操作（git commit / push、gh pr create / merge）を配布物のshell / Pythonに置かない
has_raw_publication_operation() {
  rg -n --glob '*.sh' --glob '*.py' \
    '\bgit[[:space:]]+(commit|push)\b|\bgh[[:space:]]+pr[[:space:]]+(create|merge)\b|["'"'']git["'"''][[:space:]]*,[[:space:]]*["'"''](commit|push)["'"'']|["'"'']gh["'"''][[:space:]]*,[[:space:]]*["'"'']pr["'"''][[:space:]]*,[[:space:]]*["'"''](create|merge)["'"'']' \
    "$1" >/dev/null
}
if has_raw_publication_operation "$ROOT/plugins"; then fail "配布物に素の公開操作がある"; else pass "配布物に素の公開操作が無い"; fi
mkdir -p "$TMP_ROOT/raw"
printf '%s\n' 'git push origin branch' > "$TMP_ROOT/raw/raw.sh"
printf '%s\n' 'subprocess.run(["gh", "pr", "create", "--fill"])' > "$TMP_ROOT/raw/m8b.py"
has_raw_publication_operation "$TMP_ROOT/raw" && pass "self-test: 素の公開操作を検出できる" || fail "self-test: 素の公開操作の検出"

# ── 構文 ────────────────────────────────────────────────────────────────
while IFS= read -r script; do bash -n "$script" || failed=1; done < <(find "$ROOT/scripts" "$ROOT/tests" "$PACKAGE" -type f -name '*.sh' | sort)
while IFS= read -r script; do python3 -m py_compile "$script" || failed=1; done < <(find "$PACKAGE" -type f -name '*.py' | sort)

# ── 決定論的toolの契約 ────────────────────────────────────────────────
python3 -m unittest discover -s "$ROOT/tests" -p test_verification_cli.py >/dev/null 2>&1 && pass "verify.sh のJSON出力と失敗停止" || fail "tests/test_verification_cli.py"

REVIEW="$ENTRY_DIR/respond-to-pr-review"
repo="$TMP_ROOT/repo"; mkdir -p "$repo/.harness-plugins"
cfg="$repo/.harness-plugins/respond-to-pr-review.config.yml"
cp "$REVIEW/assets/respond-to-pr-review.config.example.yml" "$cfg"
git -C "$repo" init -q -b main; printf 'a\n' > "$repo/a.txt"; git -C "$repo" add a.txt .harness-plugins; git -C "$repo" -c user.email=t@example.invalid -c user.name=t commit -qm init
gate_ok=1
python3 "$REVIEW/scripts/review-gate.py" preflight --config "$cfg" --repo "$repo" | jq -e '.status=="ready"' >/dev/null || gate_ok=0
python3 "$REVIEW/scripts/review-gate.py" permission --config "$cfg" --name review_import | jq -e '.allowed==true' >/dev/null || gate_ok=0
if python3 "$REVIEW/scripts/review-gate.py" gate --config "$cfg" --name after_assessment >/dev/null 2>&1; then gate_ok=0; fi
python3 "$REVIEW/scripts/review-gate.py" gate --config "$cfg" --name after_assessment --approved | jq -e '.status=="approved"' >/dev/null || gate_ok=0
printf 'dirty\n' > "$repo/b.txt"
if python3 "$REVIEW/scripts/review-gate.py" preflight --config "$cfg" --repo "$repo" >/dev/null 2>&1; then gate_ok=0; fi
rm "$repo/b.txt"
[ "$gate_ok" -eq 1 ] && pass "review-gate.py: preflight / permission / gate の正例と承認待ち・dirty開始" || fail "review-gate.py の正例"
reject_ok=1
if python3 "$REVIEW/scripts/review-gate.py" permission --config "$repo/.harness-plugins/missing.yml" --name modify >/dev/null 2>&1; then reject_ok=0; fi
for edit in '.permissions.commit = true' '.gates.before_push = true' 'del(.git)' '.report.timing = "later"' '.verification.commands = [""]' '.extra = 1'; do
  cp "$REVIEW/assets/respond-to-pr-review.config.example.yml" "$cfg"; yq -i "$edit" "$cfg"
  if python3 "$REVIEW/scripts/review-gate.py" permission --config "$cfg" --name modify >/dev/null 2>&1; then reject_ok=0; echo "  受理してはならない設定: $edit"; fi
done
cp "$REVIEW/assets/respond-to-pr-review.config.example.yml" "$cfg"
other="$TMP_ROOT/other"; mkdir -p "$other"; git -C "$other" init -q -b main
if python3 "$REVIEW/scripts/review-gate.py" preflight --config "$cfg" --repo "$other" >/dev/null 2>&1; then reject_ok=0; fi
[ "$reject_ok" -eq 1 ] && pass "review-gate.py: policy不在・公開操作permission/gateの混入・schema違反・別repository設定を拒否" || fail "review-gate.py の反例"

OPEN="$ENTRY_DIR/open-pull-request"
gate_sh_ok=1
python3 - "$OPEN/scripts/gate.sh" <<'PY' || gate_sh_ok=0
import json, subprocess, sys
script = sys.argv[1]
waiting = subprocess.run(["bash", script, "--report-ref", "/tmp/report.md"], capture_output=True, text=True)
assert waiting.returncode == 3 and json.loads(waiting.stdout)["status"] == "waiting_for_human"
approved = subprocess.run(["bash", script, "--report-ref", "/tmp/report.md", "--approved"], capture_output=True, text=True)
assert approved.returncode == 0 and json.loads(approved.stdout)["status"] == "approved"
invalid = subprocess.run(["bash", script, "--approved"], capture_output=True, text=True)
assert invalid.returncode == 2 and json.loads(invalid.stdout)["status"] == "invalid"
PY
[ "$gate_sh_ok" -eq 1 ] && pass "gate.sh: 承認待ち / 承認済み / 引数不備" || fail "gate.sh"
open_cfg_ok=1
for edit in '' '.conflict_report.timing = "after_resolution"'; do
  yq -o=json -I=0 '.' "$OPEN/assets/open-pull-request.config.example.yml" | jq -e "${edit:-.} | .version==1 and (.conflict_report.timing==\"before_resolution\" or .conflict_report.timing==\"after_resolution\") and (.verification.commands|type)==\"array\" and (keys|sort)==[\"conflict_report\",\"verification\",\"version\"]" >/dev/null || open_cfg_ok=0
done
yq -o=json -I=0 '.' "$OPEN/assets/open-pull-request.config.example.yml" | jq -e '.conflict_report.timing="later" | .conflict_report.timing=="before_resolution" or .conflict_report.timing=="after_resolution"' >/dev/null && open_cfg_ok=0
[ "$open_cfg_ok" -eq 1 ] && pass "open-pull-request 設定の記入例が schema（timing 2値、commands 配列、key集合）に合う" || fail "open-pull-request 設定の記入例"

# ── 消費側の契約lint（G2同期後の共有版）: 外部依存の内部名を消費側の文書・script・設定へ書いていない ──
# 検出語は兄弟checkoutの実配布物（provider package root）から作る。兄弟が無ければ緑にせず失敗させる。
lint_consumer_contract() {
  local map="$TMP_ROOT/lint-dev-map.json" status=0 runtime
  local grill="$ROOT/../grill-plugins/plugins/grill" write_doc="$ROOT/../write-doc-plugins/plugins/write-doc" awp="$ROOT/../agent-work-policy-plugins/plugins/agent-work-policy"
  for provider in "$grill" "$write_doc" "$awp"; do
    [ -d "$provider" ] || { echo "[error] 依存先の配布物checkoutが無い: $provider" >&2; return 1; }
  done
  jq -n --arg g "$(cd "$grill" && pwd -P)" --arg w "$(cd "$write_doc" && pwd -P)" --arg a "$(cd "$awp" && pwd -P)" \
    '{schema:1,dependencies:{"grill/grill":$g,"write-doc/write-doc":$w,"agent-work-policy/agent-work-policy":$a}}' > "$map" || return 1
  for runtime in claude codex; do
    HARNESS_PLUGIN_DEV_ROOTS="$map" python3 "$ROOT/scripts/lint-consumer-contract.py" --repo "$ROOT" --runtime "$runtime" || status=1
  done
  return "$status"
}
lint_consumer_contract && pass "消費側契約lint（両runtime。依存先の内部名を書いていない）" || fail "消費側契約lint"

if [ "$failed" -eq 0 ]; then echo 'Validation: passed'; else echo 'Validation: failed'; fi
[ "$failed" -eq 0 ]
