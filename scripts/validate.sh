#!/usr/bin/env bash
# Scenario: repositoryのplugin集合、manifest、marketplace、構文が一致する
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/plugin-repository-validation.XXXXXX") || exit 2
trap 'rm -rf "$TMP_ROOT"' EXIT
failed=0

validate_dependency_resolution_contract() {
  local resolver="$ROOT/shared/playbook/resolve-dependency.py"
  local fixture="$TMP_ROOT/dependency-resolution"
  local cache="$fixture/cache"
  local status=0
  local out

  mkdir -p "$fixture/empty" "$cache/fixture-market/fixture-plugin/1.0.0/.codex-plugin" "$cache/fixture-market/fixture-plugin/1.0.0/.claude-plugin"
  mkdir -p "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin" "$cache/fixture-market/fixture-plugin/9.9.9/.claude-plugin"
  for version in 1.0.0 9.9.9; do
    printf '{"name":"fixture-plugin","version":"%s"}\n' "$version" > "$cache/fixture-market/fixture-plugin/$version/.codex-plugin/plugin.json"
    printf '{"name":"fixture-plugin","version":"%s"}\n' "$version" > "$cache/fixture-market/fixture-plugin/$version/.claude-plugin/plugin.json"
  done
  printf '%s\n' '---' 'name: wrong-skill' 'description: fixture' '---' > "$cache/fixture-market/fixture-plugin/9.9.9/SKILL.md"

  local marketplace repository_plugin
  marketplace=$(jq -r '.name' "$ROOT/.agents/plugins/marketplace.json")
  repository_plugin=$(jq -r '.plugins[0].name' "$ROOT/.agents/plugins/marketplace.json")
  for runtime in codex claude; do
    out=$(HARNESS_PLUGIN_RUNTIME="$runtime" python3 "$resolver" --plugin-root "$ROOT/shared/playbook" --plugin "$repository_plugin" --marketplace "$marketplace" 2> "$fixture/repository-$runtime.err")
    jq -e --arg runtime "$runtime" --arg plugin "$repository_plugin" '.runtime==$runtime and .plugin==$plugin and .source_kind=="repository"' >/dev/null <<<"$out" || status=1

    out=$(HARNESS_PLUGIN_RUNTIME="$runtime" HARNESS_PLUGIN_CACHE_ROOT="$cache" python3 "$resolver" --plugin-root "$fixture/empty" --plugin fixture-plugin --marketplace fixture-market 2> "$fixture/cache-$runtime.err")
    jq -e --arg runtime "$runtime" '.runtime==$runtime and .version=="9.9.9" and .source_kind=="installed-cache"' >/dev/null <<<"$out" || status=1
  done

  mkdir -p "$fixture/dev/.codex-plugin" "$fixture/dev/.claude-plugin"
  printf '%s\n' '{"name":"fixture-plugin","version":"3.4.5"}' > "$fixture/dev/.codex-plugin/plugin.json"
  printf '%s\n' '{"name":"fixture-plugin","version":"3.4.5"}' > "$fixture/dev/.claude-plugin/plugin.json"
  jq -n --arg root "$fixture/dev" '{schema:1,dependencies:{"fixture-market/fixture-plugin":$root}}' > "$fixture/dev-map.json"
  out=$(HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_DEV_ROOTS="$fixture/dev-map.json" HARNESS_PLUGIN_CACHE_ROOT="$fixture/empty" python3 "$resolver" --plugin-root "$fixture/empty" --plugin fixture-plugin --marketplace fixture-market 2> "$fixture/dev.err")
  jq -e '.version=="3.4.5" and .source_kind=="dev-map"' >/dev/null <<<"$out" || status=1

  if HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$fixture/empty" python3 "$resolver" --plugin-root "$fixture/empty" --plugin missing-plugin --marketplace fixture-market >/dev/null 2> "$fixture/missing.err"; then
    status=1
  else
    rg '\[error:dependency-missing\].*plugin=missing-plugin.*marketplace=fixture-market' "$fixture/missing.err" >/dev/null || status=1
  fi

  mv "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json" "$fixture/correct-manifest.json"
  printf '%s\n' '{"name":"other-plugin","version":"9.9.9"}' > "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json"
  if HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" python3 "$resolver" --plugin-root "$fixture/empty" --plugin fixture-plugin --marketplace fixture-market >/dev/null 2> "$fixture/identity.err"; then
    status=1
  else
    rg 'manifest-identity-mismatch' "$fixture/identity.err" >/dev/null || status=1
  fi
  mv "$fixture/correct-manifest.json" "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json"

  mkdir -p "$fixture/ambiguous/.agents/plugins" "$fixture/ambiguous/.claude-plugin" "$fixture/ambiguous/plugins/caller"
  jq -n '{name:"fixture-market",plugins:[{name:"fixture-plugin",source:{source:"local",path:"./plugins/a"}},{name:"fixture-plugin",source:{source:"local",path:"./plugins/b"}}]}' > "$fixture/ambiguous/.agents/plugins/marketplace.json"
  if HARNESS_PLUGIN_RUNTIME=codex python3 "$resolver" --plugin-root "$fixture/ambiguous/plugins/caller" --plugin fixture-plugin --marketplace fixture-market >/dev/null 2> "$fixture/ambiguous.err"; then
    status=1
  else
    rg 'source_kind=repository reason=marketplace-entry' "$fixture/ambiguous.err" >/dev/null || status=1
  fi

  mkdir -p "$fixture/playbook/scripts" "$fixture/repo"
  cp "$ROOT/shared/playbook/resolve.sh" "$fixture/playbook/scripts/resolve.sh"
  cp "$ROOT/shared/playbook/resolve-dependency.py" "$fixture/playbook/scripts/resolve-dependency.py"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$fixture/playbook/scripts/validate-config.sh"
  chmod +x "$fixture/playbook/scripts/resolve.sh" "$fixture/playbook/scripts/validate-config.sh"
  printf '%s\n' 'version: 2' 'name: fixture-playbook' 'description: fixture' 'instructions:' '  execution: {directive: fixture}' 'requires:' '  - {plugin: fixture-plugin, marketplace: fixture-market}' 'steps:' '  - {id: invoke, skill: expected-skill, purpose: fixture}' > "$fixture/playbook/playbook.yml"
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" bash "$fixture/playbook/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/skill.err"; then
    status=1
  else
    rg 'steps が指すスキルが requires のプラグインに無い: expected-skill' "$fixture/skill.err" >/dev/null || status=1
  fi

  cp "$fixture/playbook/playbook.yml" "$fixture/playbook/base.yml"
  yq -o=json -I=0 '.' "$fixture/playbook/base.yml" | jq '.requires[0].version="1.0.0"' | yq -P > "$fixture/playbook/playbook.yml"
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" bash "$fixture/playbook/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/pin.err"; then status=1; fi
  yq -o=json -I=0 '.' "$fixture/playbook/base.yml" | jq '.requires[0]=.requires[0].plugin' | yq -P > "$fixture/playbook/playbook.yml"
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" bash "$fixture/playbook/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/bare.err"; then status=1; fi

  return "$status"
}

validate_publication_delegation_contract() {
  local fixture="$TMP_ROOT/publication-delegation"
  local review="$ROOT/plugins/playbooks/pull-request/pr-review-response"
  local pull="$ROOT/plugins/playbooks/pull-request/pull-request"
  local status=0

  has_raw_publication_operation() {
    local target="$1"
    rg -n --glob '*.sh' --glob '*.py' \
      '\bgit[[:space:]]+(commit|push)\b|\bgh[[:space:]]+pr[[:space:]]+(create|merge)\b|["'"'']git["'"''][[:space:]]*,[[:space:]]*["'"''](commit|push)["'"'']|["'"'']gh["'"''][[:space:]]*,[[:space:]]*["'"'']pr["'"''][[:space:]]*,[[:space:]]*["'"''](create|merge)["'"'']' \
      "$target" >/dev/null
  }

  # 公開操作の直接実行は、配布物の種類を問わず許さない。説明文は対象外にし、
  # shell と Python の実行形だけを見る。
  if has_raw_publication_operation "$ROOT/plugins"; then
    status=1
  fi
  find "$ROOT/plugins" -path '*/scripts/publish.sh' -type f -print -quit | grep -q . && status=1

  mkdir -p "$fixture"
  yq -o=json -I=0 '.' "$review/playbook.yml" > "$fixture/review.json"
  yq -o=json -I=0 '.' "$pull/playbook.yml" > "$fixture/pull.json"
  # 実物playbook自身を固有validatorへ渡す。以後の変異も同じ経路で拒否される。
  bash "$review/scripts/validate-config.sh" "$fixture/review.json" >/dev/null 2>&1 || status=1
  bash "$pull/scripts/validate-config.sh" "$fixture/pull.json" >/dev/null 2>&1 || status=1

  # M4b/M5/M5b/M6/M9: 実物と同じvalidator経路で各変異を拒否する。
  jq 'del(.steps[] | select(.id=="commit").plugin)' "$fixture/review.json" > "$fixture/m4b.json"
  bash "$review/scripts/validate-config.sh" "$fixture/m4b.json" >/dev/null 2>&1 && status=1
  # M5: 公開操作の独自permissionを再導入する変異は拒否する。
  jq '.permissions.commit=true' "$fixture/review.json" > "$fixture/m5.json"
  bash "$review/scripts/validate-config.sh" "$fixture/m5.json" >/dev/null 2>&1 && status=1
  jq '.gates.before_push=true' "$fixture/review.json" > "$fixture/m5b.json"
  bash "$review/scripts/validate-config.sh" "$fixture/m5b.json" >/dev/null 2>&1 && status=1
  # M6: base/remote/draftをplaybookへ複製する変異は拒否する。
  jq '.git={base_branch:"main",remote:"origin"} | .pull_request={draft:false}' "$fixture/pull.json" > "$fixture/m6.json"
  bash "$pull/scripts/validate-config.sh" "$fixture/m6.json" >/dev/null 2>&1 && status=1
  jq '(.steps[] | select(.id=="create-pull-request")) |= (.script="scripts/create.sh" | del(.skill))' "$fixture/pull.json" > "$fixture/m9.json"
  bash "$pull/scripts/validate-config.sh" "$fixture/m9.json" >/dev/null 2>&1 && status=1

  # M8/M8b/M12: shellとsubprocess list形式の素の公開操作を拒否する。
  mkdir -p "$fixture/plugins"
  printf '%s\n' 'git push origin branch' > "$fixture/plugins/raw.sh"
  printf '%s\n' 'subprocess.run(["gh", "pr", "create", "--fill"])' > "$fixture/plugins/m8b.py"
  printf '%s\n' 'subprocess.run(["git", "push"])' > "$fixture/plugins/m12.py"
  has_raw_publication_operation "$fixture/plugins" || status=1

  return "$status"
}

validate_ready_for_review_delegation_contract() {
  local fixture="$TMP_ROOT/ready-for-review"
  local runner="$ROOT/plugins/playbooks/pull-request/pull-request/scripts/ready-for-review.sh"
  local status=0
  local out code

  mkdir -p "$fixture/policy/scripts" "$fixture/repo"
  printf '%s\n' '{}' > "$fixture/policy/config.yml"
  cat > "$fixture/policy/scripts/prepare.sh" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "$fixture/policy/config.yml"
EOF
  cat > "$fixture/policy/scripts/control.py" <<'EOF'
#!/usr/bin/env python3
import json
import os
import sys

if "--help" in sys.argv:
    print(os.environ.get("FIXTURE_CAPABILITY", "ready-for-review"))
    raise SystemExit(0)
if sys.argv[1:2] != ["ready-for-review"]:
    raise SystemExit(2)
with open(os.environ["FIXTURE_CALL"], "a", encoding="utf-8") as handle:
    handle.write(" ".join(sys.argv[1:]) + "\n")
mode = os.environ["FIXTURE_MODE"]
if mode == "failed":
    print(json.dumps({"status": "failed"}))
    raise SystemExit(3)
print(json.dumps({"status": "ready", "changed": mode == "draft"}))
EOF
  chmod +x "$fixture/policy/scripts/prepare.sh" "$fixture/policy/scripts/control.py"

  for mode in draft published; do
    rm -f "$fixture/call"
    out=$(FIXTURE_MODE="$mode" FIXTURE_CALL="$fixture/call" "$runner" --policy-root="$fixture/policy" --repo="$fixture/repo" --pr=42 --internal-review-complete) || status=1
    expected_changed=false
    [ "$mode" = draft ] && expected_changed=true
    jq -e --argjson changed "$expected_changed" '.status=="ready" and .changed==$changed' >/dev/null <<<"$out" || status=1
    [ "$(wc -l < "$fixture/call")" -eq 1 ] || status=1
    rg 'ready-for-review --config .+ --repo .+ --pr 42' "$fixture/call" >/dev/null || status=1
  done

  if out=$(FIXTURE_MODE=failed FIXTURE_CALL="$fixture/call" "$runner" --policy-root "$fixture/policy" --repo "$fixture/repo" --pr 42 --internal-review-complete); then
    status=1
  else
    code=$?
    [ "$code" -eq 3 ] || status=1
    jq -e '.status=="failed"' >/dev/null <<<"$out" || status=1
  fi

  if out=$(FIXTURE_CAPABILITY=other-command FIXTURE_MODE=draft FIXTURE_CALL="$fixture/call" "$runner" --policy-root "$fixture/policy" --repo "$fixture/repo" --pr 42 --internal-review-complete); then
    status=1
  else
    code=$?
    [ "$code" -eq 2 ] || status=1
    jq -e '.status=="invalid" and .reason=="policy_capability_missing"' >/dev/null <<<"$out" || status=1
  fi

  return "$status"
}

validate_pull_request_resolver_contract() {
  local fixture="$TMP_ROOT/pull-request-resolver"
  local pull="$ROOT/plugins/playbooks/pull-request/pull-request"
  local status=0
  local out

  mkdir -p "$fixture/repo" "$fixture/empty-cache" "$fixture/policy/.codex-plugin" "$fixture/write-doc/.codex-plugin"
  printf '%s\n' '{"name":"agent-work-policy","version":"0.1.6"}' > "$fixture/policy/.codex-plugin/plugin.json"
  printf '%s\n' '---' 'name: work-with-policy' 'description: fixture' '---' > "$fixture/policy/SKILL.md"
  printf '%s\n' '{"name":"write-doc","version":"0.6.0"}' > "$fixture/write-doc/.codex-plugin/plugin.json"
  printf '%s\n' '---' 'name: write-doc' 'description: fixture' '---' > "$fixture/write-doc/SKILL.md"
  jq -n --arg policy "$fixture/policy" --arg write_doc "$fixture/write-doc" \
    '{schema:1,dependencies:{"agent-work-policy/agent-work-policy":$policy,"write-doc/write-doc":$write_doc}}' > "$fixture/dev-roots.json"
  out=$(XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$fixture/empty-cache" HARNESS_PLUGIN_DEV_ROOTS="$fixture/dev-roots.json" \
    bash "$pull/scripts/resolve.sh" "$fixture/repo") || status=1
  yq -o=json -I=0 '.' <<<"$out" | jq -e '
    .playbook.name=="pull-request" and
    ([.playbook.steps[].id] | index("ready-for-review") | not) and
    (.playbook.steps | length==6)
  ' >/dev/null || status=1
  return "$status"
}

validate_manifest_identity_contract() {
  local fixture="$TMP_ROOT/manifest-identity"
  local source="$ROOT/plugins/skills/pull-request/pr-create"
  local status=0
  local version
  version=$(jq -r '.plugins[] | select(.name=="pr-create") | .version' "$ROOT/.agents/plugins/marketplace.json")
  mkdir -p "$fixture"
  cp "$source/.claude-plugin/plugin.json" "$fixture/claude.json"
  cp "$source/.codex-plugin/plugin.json" "$fixture/codex.json"
  jq -s -e --arg n pr-create --arg v "$version" '
    length==2 and all(.[]; .name==$n and .version==$v)
  ' "$fixture/claude.json" "$fixture/codex.json" >/dev/null || status=1
  # D5c: Codex manifestだけが別versionなら、両runtimeのidentityは不一致である。
  jq '.version="9.9.9"' "$fixture/codex.json" > "$fixture/codex-mutated.json"
  if jq -s -e --arg n pr-create --arg v "$version" '
    length==2 and all(.[]; .name==$n and .version==$v)
  ' "$fixture/claude.json" "$fixture/codex-mutated.json" >/dev/null; then
    status=1
  fi
  return "$status"
}
jq -r '.plugins[].name' "$ROOT/.agents/plugins/marketplace.json" | sort > "$TMP_ROOT/expected"
find "$ROOT/plugins" -path '*/.codex-plugin/plugin.json' -type f -exec jq -r '.name' {} \; | sort > "$TMP_ROOT/actual"
diff -u "$TMP_ROOT/expected" "$TMP_ROOT/actual" >/dev/null || failed=1
for market in .agents/plugins/marketplace.json .claude-plugin/marketplace.json; do
  jq -r '.plugins[].name' "$ROOT/$market" | sort > "$TMP_ROOT/market"
  diff -u "$TMP_ROOT/expected" "$TMP_ROOT/market" >/dev/null || failed=1
done
while IFS='|' read -r name version rel; do
  jq -s -e --arg n "$name" --arg v "$version" '
    length==2 and all(.[]; .name==$n and .version==$v)
  ' "$ROOT/$rel/.codex-plugin/plugin.json" "$ROOT/$rel/.claude-plugin/plugin.json" >/dev/null || failed=1
done < <(jq -r '.plugins[] | [.name,.version,(.source.path | ltrimstr("./"))] | join("|")' "$ROOT/.agents/plugins/marketplace.json")
bash "$ROOT/scripts/validate-marketplace.sh" "$ROOT" || failed=1
bash "$ROOT/scripts/test-marketplace-validation.sh" || failed=1
while IFS= read -r pb; do
  yq -o=json -I=0 '.' "$pb" | jq -e '.version==2 and (.requires|length>0) and all(.requires[]; type=="object" and ((keys|sort)==["marketplace","plugin"]))' >/dev/null || failed=1
  root=$(dirname "$pb")
  cmp -s "$ROOT/shared/playbook/resolve.sh" "$root/scripts/resolve.sh" || failed=1
  cmp -s "$ROOT/shared/playbook/resolve-dependency.py" "$root/scripts/resolve-dependency.py" || failed=1
done < <(find "$ROOT/plugins/playbooks" -name playbook.yml -type f 2>/dev/null | sort)
# 配布物ごとの入口は、共有正本から逸脱させない。公開操作を委譲する
# playbookも、単体配布時にはこの複製だけで設定解決できる必要がある。
while IFS= read -r script; do
  cmp -s "$ROOT/shared/prepare.sh" "$script" || failed=1
done < <(find "$ROOT/plugins" -path '*/scripts/prepare.sh' -type f | sort)
# 公開Git操作を行うplaybookは、Agent Work Policyを唯一の所有者として宣言する。
for pb in \
  "$ROOT/plugins/playbooks/pull-request/pull-request/playbook.yml" \
  "$ROOT/plugins/playbooks/pull-request/pr-review-response/playbook.yml"; do
  yq -o=json -I=0 '.requires' "$pb" | jq -e '
    any(.[]; .plugin == "agent-work-policy" and .marketplace == "agent-work-policy")
  ' >/dev/null || failed=1
done
while IFS= read -r script; do bash -n "$script" || failed=1; done < <(find "$ROOT" -type f -name '*.sh' | sort)
while IFS= read -r script; do PYTHONPYCACHEPREFIX="$TMP_ROOT/pycache" python3 -m py_compile "$script" || failed=1; done < <(find "$ROOT" -type f -name '*.py' | sort)
validate_dependency_resolution_contract || failed=1
validate_publication_delegation_contract || failed=1
validate_ready_for_review_delegation_contract || failed=1
validate_pull_request_resolver_contract || failed=1
validate_manifest_identity_contract || failed=1
if [ "$failed" -eq 0 ]; then echo 'Validation: passed'; else echo 'Validation: failed'; fi
[ "$failed" -eq 0 ]
