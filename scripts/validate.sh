#!/usr/bin/env bash
# Scenario: pull-request package が公開入口3つ（open-pull-request / resolve-pr-conflicts / respond-to-pr-review）で自己完結し、
#           各入口の決定論的toolが閉じた契約を守り、公開Git操作を自前で実行しない
# 機械検査は宣言と実体の対応、隣接playbook.ymlの契約、設定fileのschemaと config.py check|read の契約、
# gate / review-gate / verify の入出力、平時/例外の分離（open-pull-request が競合時だけ resolve-pr-conflicts を skill: で呼ぶ）、
# 素の公開操作の不在だけを判定する。競合解消の妥当性、review採否の判断、SKILL本文の判断基準の十分性は意味評価として残す。
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

# ── 保守tool（基準資料は兄弟checkout harness-tools だけ。複製を持たず、無ければ止まる。fixtureで代用しない） ──
TOOLS="$ROOT/../harness-tools/tools"
[ -d "$TOOLS" ] || { echo "[error] 兄弟 checkout harness-tools が無い: $TOOLS" >&2; exit 2; }
python3 "$TOOLS/validate-plugin-repository.py" "$ROOT" && pass "root契約（配置・manifest・隣接playbook.yml・禁止参照形）" || fail "root契約"
python3 "$TOOLS/validate-plugin-repository.py" --self-test >/dev/null && pass "root validatorのself-test" || fail "root validatorのself-test"
python3 "$TOOLS/test-hardening.py" --repository "$ROOT" >"$TMP_ROOT/hardening.out" 2>&1 && pass "保守toolの回帰検査（CIのSHA固定・公開入口の一意性・doctorの読み取り専用性を含む）" || { cat "$TMP_ROOT/hardening.out"; fail "保守toolの回帰検査"; }
ENTRIES=(open-pull-request resolve-pr-conflicts respond-to-pr-review)
OPEN="$ENTRY_DIR/open-pull-request"
RESOLVE="$ENTRY_DIR/resolve-pr-conflicts"
REVIEW="$ENTRY_DIR/respond-to-pr-review"

# ── 配置と identity ──────────────────────────────────────────────────────
for market in .claude-plugin/marketplace.json .agents/plugins/marketplace.json; do
  if jq -e --arg v "$(jq -r .version "$ROOT/plugins/pull-request/.claude-plugin/plugin.json")" '.name=="pull-request" and (.plugins|length)==1 and .plugins[0].name=="pull-request" and .plugins[0].version==$v
            and ((.plugins[0].source=="./plugins/pull-request") or (.plugins[0].source=={"source":"local","path":"./plugins/pull-request"}))' "$ROOT/$market" >/dev/null; then
    pass "$market identityとsource"
  else
    fail "$market identityとsource"
  fi
done
claude_identity=$(jq -c '{name,version,skills,harness:.metadata.harness}' "$PACKAGE/.claude-plugin/plugin.json")
codex_identity=$(jq -c '{name,version,skills,harness:.metadata.harness}' "$PACKAGE/.codex-plugin/plugin.json")
[ "$claude_identity" = "$codex_identity" ] && pass "両runtime manifestのidentity一致" || fail "両runtime manifestのidentity一致"
jq -e '.skills==["./skills/open-pull-request","./skills/resolve-pr-conflicts","./skills/respond-to-pr-review"]
       and .metadata.harness=={"marketplace":"pull-request","contractVersion":1}' "$PACKAGE/.codex-plugin/plugin.json" >/dev/null \
  && pass "公開入口3つ、playbooks / internalPlugins / implements 無し" || fail "manifestの公開宣言"
manifest_dirs=$(find "$ROOT/plugins" -type d \( -name '.claude-plugin' -o -name '.codex-plugin' \) | sed "s#^$ROOT/##" | sort | tr '\n' ' ')
[ "$manifest_dirs" = "plugins/pull-request/.claude-plugin plugins/pull-request/.codex-plugin " ] \
  && pass "runtime manifest directoryはpackage rootの2つだけ" || fail "runtime manifest directoryが余分または欠落: $manifest_dirs"
skill_dirs=$(find "$ENTRY_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | tr '\n' ' ')
[ "$skill_dirs" = "open-pull-request resolve-pr-conflicts respond-to-pr-review " ] && pass "skills/直下は公開入口3つだけ" || fail "skills/直下: $skill_dirs"
[ "$(find "$ROOT/plugins" -name SKILL.md -type f | wc -l | tr -d ' ')" -eq 3 ] && pass "SKILL.mdは公開入口の3本だけ（内部skillなし）" || fail "SKILL.mdの本数"
[ "$(find "$ROOT/plugins" -type l | wc -l | tr -d ' ')" -eq 0 ] && pass "配布物にsymlinkなし" || fail "配布物にsymlinkがある"

# ── 公開入口ごとの構造 ─────────────────────────────────────────────────
for entry in "${ENTRIES[@]}"; do
  dir="$ENTRY_DIR/$entry"
  name=$(awk 'NR==1 { if ($0 != "---") exit 2; next } $0=="---" { exit } { print }' "$dir/SKILL.md" | yq -r '.name')
  [ "$name" = "$entry" ] && pass "$entry: SKILL frontmatter name" || fail "$entry: SKILL frontmatter name = $name"
  pb=$(yq -o=json -I=0 '.' "$dir/playbook.yml")
  jq -e --arg n "$entry" '.version==2 and .name==$n
      and (.requires|length)>=1 and all(.requires[]; .marketplace==.plugin and (.plugin=="agent-work-policy" or .plugin=="write-doc"))
      and (.inputs|index("document_destination")) and (.inputs|index("references")) and ((.inputs|index("output_target"))|not)
      and ((.steps|map(.id)|unique|length)==(.steps|length))
      and all(.steps[]; ([has("agent_work"),has("script"),has("skill"),has("playbook")]|map(select(.))|length)==1)
      and all(.steps[]|select(has("playbook")); .playbook=="agent-work-policy" or .playbook=="write-doc")
      and all(.steps[]|select(has("playbook")); (has("input")|not) or ((.input|keys)==["document_type"]))
      and all(.steps[]|select(has("skill")); .skill=="resolve-pr-conflicts")
      and ((.. | objects | has("output_to")) | not)
      and ((.|has("permissions"))|not) and ((.|has("gates"))|not) and ((.|has("git"))|not) and ((.|has("verification"))|not) and ((.|has("conflict_report"))|not) and ((.|has("report"))|not)' <<<"$pb" >/dev/null \
    && pass "$entry: playbook.yml identity・外部requires・references入力・工程種別・policy値の不在" || fail "$entry: playbook.yml"
  scripts_ok=1
  while IFS= read -r script; do [ -f "$dir/$script" ] || scripts_ok=0; done < <(jq -r '.steps[]|select(has("script")).script' <<<"$pb")
  [ "$scripts_ok" -eq 1 ] && pass "$entry: steps.script は入口内の実在file" || fail "$entry: steps.script の参照先"
  [ -f "$dir/assets/$entry.config.example.yml" ] && pass "$entry: 設定の記入例がある" || fail "$entry: 設定の記入例"
  jq -e '.steps[0].id=="read-policy" and .steps[0].script=="scripts/config.py"' <<<"$pb" >/dev/null \
    && pass "$entry: 最初の工程が scripts/config.py で設定を読む" || fail "$entry: read-policy 工程"
  if rg -n --fixed-strings -e '${.' -e '<!-- BEGIN shared:' -e 'CLAUDE_PLUGIN_ROOT' -e 'BUNDLE_ROOT' "$dir/SKILL.md" "$dir/playbook.yml" $( [ -d "$dir/references" ] && echo "$dir/references" ) >/dev/null \
    || rg -n 'prepare\.sh|resolve\.sh|run-config\.py|state\.py|work-with-policy|pr-conflict-inspect|pr-conflict-resolve|pr-create|pr-review-assess|pr-review-apply|pr-review-verify|--config ' "$dir/SKILL.md" $( [ -d "$dir/references" ] && echo "$dir/references" ) >/dev/null; then
    fail "$entry: 禁止参照形・旧runtime・旧内部名・設定pathの引数渡しが残っている"
  else
    pass "$entry: 禁止参照形・旧runtime・旧内部名・設定pathの引数渡しが無い"
  fi
done

# ── 平時（open-pull-request）と例外（resolve-pr-conflicts）の分離 ─────────
# 基準資料: 各入口の隣接 playbook.yml と manifest の skills（同package の公開入口の集合）
# 入力: skills/open-pull-request/playbook.yml、skills/resolve-pr-conflicts/playbook.yml、skills/respond-to-pr-review/playbook.yml
# 正規化: yq v4 で JSON 化し、steps を宣言順の list、requires を plugin 名の集合として読む
# 合格述語: open-pull-request は agent-work-policy だけを requires し、steps の id 列が平時フローの順（read-policy → workspace → detect-conflicts →
#           resolve-conflicts → verify → prepare-pull-request → push → create-pull-request → approve-ready-for-review → ready-for-review）で、
#           skill: 工程が {id: resolve-conflicts, skill: resolve-pr-conflicts, when: conflict_state.has_conflicts} の 1 つだけ、write-doc 工程を持たず、
#           agent-work-policy へ委譲する工程 id が [workspace, push, create-pull-request, ready-for-review]。
#           resolve-pr-conflicts は write-doc と agent-work-policy を requires し、agent-work-policy へ委譲する工程が [workspace] だけ、skill: 工程を持たず、
#           read-policy が conflict_report を provides し、conflict_report を when で参照する工程がそれを needs し、before_resolution の解消は承認を開始条件に持つ。
#           respond-to-pr-review は agent-work-policy へ [commit, push] だけを委譲し、read-policy が report を provides し、report.* を when で参照する工程がそれを needs する
# 失敗時の診断: 入口名と、どの述語（requires / 工程 id 列 / skill 工程 / 委譲 id / provides・needs）が不一致か
# 正例: 現行の 3 playbook
# 反例: open-pull-request が write-doc 工程を持つ、skill: 工程に when が無い、resolve-pr-conflicts が push 工程を持つ、read-policy が conflict_report を provides しない
# 境界例: 工程 id が同じでも順序だけ違う playbook は不合格（id 列を配列として比べる）
# 意味評価として残す範囲: 平時と例外の分け方が利用者の 1 つの仕事を完了させるか、競合検出の方法が十分か、when の条件が業務上正しいか
open_pb=$(yq -o=json -I=0 '.' "$OPEN/playbook.yml")
resolve_pb=$(yq -o=json -I=0 '.' "$RESOLVE/playbook.yml")
review_pb=$(yq -o=json -I=0 '.' "$REVIEW/playbook.yml")
jq -e '[.steps[]|select(.playbook=="agent-work-policy")|.id]==["workspace","push","create-pull-request","ready-for-review"]
       and ((.requires|map(.plugin))==["agent-work-policy"])
       and ([.steps[]|select(has("skill"))|{id,skill,when}]==[{"id":"resolve-conflicts","skill":"resolve-pr-conflicts","when":"conflict_state.has_conflicts"}])
       and ([.steps[]|select(has("playbook") and .playbook=="write-doc")]|length)==0
       and (.steps|map(.id))==["read-policy","workspace","detect-conflicts","resolve-conflicts","verify","prepare-pull-request","push","create-pull-request","approve-ready-for-review","ready-for-review"]
       and ((.steps[]|select(.id=="detect-conflicts")).provides|index("conflict_state"))
       and ((.steps[]|select(.id=="resolve-conflicts")).needs|index("document_destination"))
       and ((.steps[]|select(.id=="resolve-conflicts")).needs|index("references"))' <<<"$open_pb" >/dev/null \
  && pass "open-pull-request: 平時フロー（設定→照会→競合検出→[競合時だけ resolve-pr-conflicts を skill: で]→検証→PR準備→push→PR作成→受付gate）で、公開Git操作4件は agent-work-policy へ委譲、資料化工程を持たない" \
  || fail "open-pull-request: 平時フローの構造"
jq -e '[.steps[]|select(.playbook=="agent-work-policy")|.id]==["workspace"]
       and ((.requires|map(.plugin)|sort)==["agent-work-policy","write-doc"])
       and ([.steps[]|select(has("skill"))]|length)==0
       and (.steps|map(.id))==["read-policy","workspace","inspect-conflicts","report-before-resolution","approve-conflict-proposal","resolve-conflicts","report-after-resolution","report"]
       and (.steps[0].provides|index("conflict_report"))
       and all(.steps[]|select(has("when") and (.when|test("conflict_report"))); (.needs|index("conflict_report")))
       and ((.steps[]|select(.id=="resolve-conflicts")).conditional_needs|map(.needs[])|index("conflict_proposal_approved"))' <<<"$resolve_pb" >/dev/null \
  && pass "resolve-pr-conflicts: 照会だけを agent-work-policy へ委譲し、push / PR作成を持たず、設定値 conflict_report は read-policy の provides から when 参照工程へ到達し、before_resolution では承認が解消の開始条件" \
  || fail "resolve-pr-conflicts: 例外フローの構造"
jq -e '[.steps[]|select(.playbook=="agent-work-policy")|.id]==["commit","push"] and (.steps[]|select(.id=="assessment-gate")|has("when")) and ((.steps[]|select(.id=="assess")).needs|index("review_import_allowed"))
       and (.steps[0].provides|index("report"))
       and all(.steps[]|select(has("when") and (.when|test("report\\."))); (.needs|index("report")))' <<<"$review_pb" >/dev/null \
  && pass "respond-to-pr-review: commit / push は agent-work-policy へ委譲、accept 0件分岐とreview取込permissionの順序、設定値 report は read-policy の provides から when 参照工程へ到達" || fail "respond-to-pr-review: 委譲と分岐"
# gate.py と approval.py の複製一致 — 基準資料: open-pull-request/scripts/ の同名file。入力: 他の入口の同名file。正規化: byte 列。合格述語: cmp が一致。
# 失敗時の診断: 2 入口の path。正例: 現行。反例: 片方だけ編集。境界例: 改行 code の差も不合格。意味評価として残す範囲: gate の意味（何を承認するか）
cmp -s "$OPEN/scripts/gate.py" "$RESOLVE/scripts/gate.py" && pass "gate.py は2入口でbyte一致（同じ基準資料の複製）" || fail "gate.py が2入口で異なる"
cmp -s "$OPEN/scripts/approval.py" "$RESOLVE/scripts/approval.py" && cmp -s "$OPEN/scripts/approval.py" "$REVIEW/scripts/approval.py" \
  && pass "approval.py は3入口でbyte一致（同じ基準資料の複製）" || fail "approval.py が3入口で異なる"

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

# ── config.py check|read の共通契約（3入口） ─────────────────────────────
# 基準資料: 各入口の assets/<入口>.config.example.yml と、各 SKILL.md 手順 1 が定める config.py の契約（M-05 / M-16）
# 入力: 一時 git repository の .harness-plugins/<入口>.config.yml（記入例を写し、yq で 1 点だけ変えた複製）、git repository でない一時 directory
# 正規化: stdout を JSON 1 文書として jq で読み、終了 code と組で見る。stdin は /dev/null
# 合格述語: check は exit 0 と {"status":"ok","config":<固定 path>}、read は exit 0 と {"config":<固定 path>,"values":{version:1, verification.commands: 配列, …}}。
#           記入例を壊した複製は exit 2 と reason=schema_violation（error 非空）、YAML として読めない file も schema_violation、
#           file 不在は reason=policy_missing と config=<固定 path>、git repository でなければ reason=not_a_git_repository と config=null
# 失敗時の診断: 入口名、どの入力（正例 / 変更した key / 不在 / 非 git）で、期待した exit code と JSON のどれが違ったか
# 正例: 記入例そのまま（check / read）、sub-directory を --repo に渡しても git root の固定 path を解決する
# 反例: 未知 key、必須 key の欠落、空 command、version ≠ 1、許容外の timing、公開 Git 操作の permission / gate の混入、YAML 不正、file 不在、非 git
# 境界例: sub-directory からの git root 解決（受理）、open-pull-request の設定に conflict_report を足す（未知 key として拒否）
# 意味評価として残す範囲: 設定 key の意味と既定値の妥当性、SKILL.md の契約記述が tool の実装と読み手に十分か
config_contract() {
  local entry=$1; shift
  local dir="$ENTRY_DIR/$entry" repo="$TMP_ROOT/cfg-$entry" ok=1 out
  mkdir -p "$repo/.harness-plugins"; git -C "$repo" init -q -b main
  cp "$dir/assets/$entry.config.example.yml" "$repo/.harness-plugins/$entry.config.yml"
  out=$(python3 "$dir/scripts/config.py" check --repo "$repo" </dev/null) && jq -e --arg c "$repo/.harness-plugins/$entry.config.yml" '.status=="ok" and (.config|endswith("/.harness-plugins/'"$entry"'.config.yml"))' <<<"$out" >/dev/null || { ok=0; echo "  check の正例: $out"; }
  out=$(python3 "$dir/scripts/config.py" read --repo "$repo" </dev/null) && jq -e '(.config|endswith("/.harness-plugins/'"$entry"'.config.yml")) and (.values|type)=="object" and .values.version==1 and (.values.verification.commands|type)=="array"' <<<"$out" >/dev/null || { ok=0; echo "  read の正例: $out"; }
  out=$(python3 "$dir/scripts/config.py" read --repo "$repo/.harness-plugins" </dev/null) && jq -e '(.config|endswith("/.harness-plugins/'"$entry"'.config.yml"))' <<<"$out" >/dev/null || { ok=0; echo "  sub-directory から git root を解決: $out"; }
  for edit in "$@"; do
    cp "$dir/assets/$entry.config.example.yml" "$repo/.harness-plugins/$entry.config.yml"; yq -i "$edit" "$repo/.harness-plugins/$entry.config.yml"
    out=$(python3 "$dir/scripts/config.py" read --repo "$repo" </dev/null); code=$?
    [ "$code" -eq 2 ] && jq -e '.reason=="schema_violation" and (.error|length)>0' <<<"$out" >/dev/null || { ok=0; echo "  schema_violation で拒否すべき設定: $edit -> exit $code $out"; }
    out=$(python3 "$dir/scripts/config.py" check --repo "$repo" </dev/null); code=$?
    [ "$code" -eq 2 ] || { ok=0; echo "  check も拒否すべき設定: $edit"; }
  done
  printf '%s\n' 'version: [1' > "$repo/.harness-plugins/$entry.config.yml"
  out=$(python3 "$dir/scripts/config.py" read --repo "$repo" </dev/null); code=$?
  [ "$code" -eq 2 ] && jq -e '.reason=="schema_violation"' <<<"$out" >/dev/null || { ok=0; echo "  YAML不正: exit $code $out"; }
  rm "$repo/.harness-plugins/$entry.config.yml"
  out=$(python3 "$dir/scripts/config.py" read --repo "$repo" </dev/null); code=$?
  [ "$code" -eq 2 ] && jq -e '.reason=="policy_missing" and (.config|endswith("/.harness-plugins/'"$entry"'.config.yml"))' <<<"$out" >/dev/null || { ok=0; echo "  policy_missing: exit $code $out"; }
  mkdir -p "$TMP_ROOT/not-git-$entry"
  out=$(python3 "$dir/scripts/config.py" check --repo "$TMP_ROOT/not-git-$entry" </dev/null); code=$?
  [ "$code" -eq 2 ] && jq -e '.reason=="not_a_git_repository" and .config==null' <<<"$out" >/dev/null || { ok=0; echo "  not_a_git_repository: exit $code $out"; }
  [ "$ok" -eq 1 ] && pass "$entry config.py: check / read の正例、schema_violation・YAML不正・policy_missing・not_a_git_repository の反例、stdin不要" || fail "$entry config.py の契約"
}
config_contract open-pull-request '.extra = 1' 'del(.verification)' '.verification.commands = [""]' '.version = 2' '.conflict_report = {"timing":"before_resolution"}'
config_contract resolve-pr-conflicts '.conflict_report.timing = "later"' '.extra = 1' 'del(.verification)' '.verification.commands = [""]' 'del(.conflict_report)'
config_contract respond-to-pr-review '.permissions.commit = true' '.gates.before_push = true' 'del(.git)' '.report.timing = "later"' '.verification.commands = [""]' '.extra = 1'

# ── 決定論的toolの契約 ────────────────────────────────────────────────
python3 -m unittest discover -s "$ROOT/tests" -p test_verification_cli.py >/dev/null 2>&1 && pass "verify.sh のJSON出力と失敗停止" || fail "tests/test_verification_cli.py"

repo="$TMP_ROOT/repo"; mkdir -p "$repo/.harness-plugins"
cfg="$repo/.harness-plugins/respond-to-pr-review.config.yml"
cp "$REVIEW/assets/respond-to-pr-review.config.example.yml" "$cfg"
git -C "$repo" init -q -b main; printf 'a\n' > "$repo/a.txt"; git -C "$repo" add a.txt .harness-plugins; git -C "$repo" -c user.email=t@example.invalid -c user.name=t commit -qm init
gate_ok=1
python3 "$REVIEW/scripts/review-gate.py" preflight --repo "$repo" | jq -e '.status=="ready"' >/dev/null || gate_ok=0
python3 "$REVIEW/scripts/review-gate.py" permission --repo "$repo" --name review_import | jq -e '.allowed==true' >/dev/null || gate_ok=0
if python3 "$REVIEW/scripts/review-gate.py" gate --repo "$repo" --name after_assessment --pr 7 >/dev/null 2>&1; then gate_ok=0; fi
scope='{"actions":["pull-request/after-assessment","merge"],"pull_requests":[7],"until":"2999-01-01T00:00:00+00:00","quote":["評価はそれでいい"]}'
python3 "$REVIEW/scripts/review-gate.py" gate --repo "$repo" --name after_assessment --pr 7 --approval "$scope" | jq -e '.status=="allowed"' >/dev/null || gate_ok=0
out=$(python3 "$REVIEW/scripts/review-gate.py" gate --repo "$repo" --name after_modify --pr 7 --approval "$scope"); [ "$?" -eq 3 ] && jq -e '.outside_approval==["action"]' <<<"$out" >/dev/null || gate_ok=0
python3 "$REVIEW/scripts/review-gate.py" gate --repo "$repo" --name after_assessment --pr 7 --approval '{"actions":["pull-request/after-assessment"]}' >/dev/null 2>&1; [ "$?" -eq 2 ] || gate_ok=0
printf 'dirty\n' > "$repo/b.txt"
if python3 "$REVIEW/scripts/review-gate.py" preflight --repo "$repo" >/dev/null 2>&1; then gate_ok=0; fi
rm "$repo/b.txt"
[ "$gate_ok" -eq 1 ] && pass "review-gate.py: preflight / permission / gate の正例と承認待ち・dirty開始" || fail "review-gate.py の正例"
reject_ok=1
rm "$cfg"
if python3 "$REVIEW/scripts/review-gate.py" permission --repo "$repo" --name modify >/dev/null 2>&1; then reject_ok=0; fi
for edit in '.permissions.commit = true' '.gates.before_push = true' 'del(.git)' '.report.timing = "later"' '.verification.commands = [""]' '.extra = 1'; do
  cp "$REVIEW/assets/respond-to-pr-review.config.example.yml" "$cfg"; yq -i "$edit" "$cfg"
  if python3 "$REVIEW/scripts/review-gate.py" permission --repo "$repo" --name modify >/dev/null 2>&1; then reject_ok=0; echo "  受理してはならない設定: $edit"; fi
done
cp "$REVIEW/assets/respond-to-pr-review.config.example.yml" "$cfg"
other="$TMP_ROOT/other"; mkdir -p "$other"
if python3 "$REVIEW/scripts/review-gate.py" preflight --repo "$other" >/dev/null 2>&1; then reject_ok=0; fi
if python3 "$REVIEW/scripts/review-gate.py" gate --repo "$repo" --name unknown_gate >/dev/null 2>&1; then reject_ok=0; fi
[ "$reject_ok" -eq 1 ] && pass "review-gate.py: policy不在・公開操作permission/gateの混入・schema違反・git repositoryでない・未知gateを拒否" || fail "review-gate.py の反例"

for entry in open-pull-request resolve-pr-conflicts; do
  gate_sh_ok=1
  python3 - "$ENTRY_DIR/$entry/scripts" <<'PY' || gate_sh_ok=0
import json, subprocess, sys
from datetime import datetime, timezone
scripts = sys.argv[1]
sys.path.insert(0, scripts)
import approval
gate = [sys.executable, f"{scripts}/gate.py", "--action", "pull-request/resolve-conflicts", "--branch", "agent/fix-a"]
scope = {"actions": ["pull-request/resolve-conflicts", "push"], "branches": ["agent/"], "until": "2999-01-01T00:00:00+00:00", "quote": ["この方針で解消していい"]}
waiting = subprocess.run(gate, capture_output=True, text=True)
assert waiting.returncode == 3 and json.loads(waiting.stdout)["status"] == "waiting_for_human"
approved = subprocess.run(gate + ["--approval", json.dumps(scope)], capture_output=True, text=True)
assert approved.returncode == 0 and json.loads(approved.stdout)["status"] == "allowed"
outside = subprocess.run(gate + ["--approval", json.dumps({**scope, "branches": ["agent/other"]})], capture_output=True, text=True)
assert outside.returncode == 3 and json.loads(outside.stdout)["outside_approval"] == ["branch"]
for broken in ({**scope, "until": "2999-01-01T00:00:00"}, {**scope, "quote": []}, {k: v for k, v in scope.items() if k != "quote"}, {k: v for k, v in scope.items() if k != "branches"}, {**scope, "targets": ["x"]}):
    invalid = subprocess.run(gate + ["--approval", json.dumps(broken)], capture_output=True, text=True)
    assert invalid.returncode == 2 and json.loads(invalid.stdout)["status"] == "invalid", broken
missing = subprocess.run([sys.executable, f"{scripts}/gate.py", "--action", "pull-request/resolve-conflicts", "--pr", "1", "--branch", "agent/x"], capture_output=True, text=True)
assert missing.returncode == 2
edge = datetime(2999, 1, 1, tzinfo=timezone.utc)
assert approval.mismatch(approval.parse(json.dumps(scope)), "pull-request/resolve-conflicts", None, "agent/fix-a", edge) == ["until"]
PY
  [ "$gate_sh_ok" -eq 1 ] && pass "$entry gate.py: 承認待ち / 承認範囲の内と外 / 形の不正 / 期限の境界" || fail "$entry gate.py"
done
yq -o=json -I=0 '.' "$OPEN/assets/open-pull-request.config.example.yml" | jq -e '.version==1 and (.verification.commands|type)=="array" and (keys|sort)==["verification","version"]' >/dev/null \
  && pass "open-pull-request 設定の記入例が schema（version、commands 配列だけ。timing を持たない）に合う" || fail "open-pull-request 設定の記入例"
resolve_cfg_ok=1
for edit in '' '.conflict_report.timing = "after_resolution"'; do
  yq -o=json -I=0 '.' "$RESOLVE/assets/resolve-pr-conflicts.config.example.yml" | jq -e "${edit:-.} | .version==1 and (.conflict_report.timing==\"before_resolution\" or .conflict_report.timing==\"after_resolution\") and (.verification.commands|type)==\"array\" and (keys|sort)==[\"conflict_report\",\"verification\",\"version\"]" >/dev/null || resolve_cfg_ok=0
done
[ "$resolve_cfg_ok" -eq 1 ] && pass "resolve-pr-conflicts 設定の記入例が schema（timing 2値、commands 配列、key集合）に合う" || fail "resolve-pr-conflicts 設定の記入例"

# ── 消費側の契約lint（harness-tools）: 外部依存の内部名を消費側の文書・script・設定へ書いていない ──
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
    HARNESS_PLUGIN_DEV_ROOTS="$map" python3 "$TOOLS/lint-consumer-contract.py" --repo "$ROOT" --runtime "$runtime" || status=1
  done
  return "$status"
}
lint_consumer_contract && pass "消費側契約lint（両runtime。依存先の内部名を書いていない）" || fail "消費側契約lint"

if [ "$failed" -eq 0 ]; then echo 'Validation: passed'; else echo 'Validation: failed'; fi
[ "$failed" -eq 0 ]
