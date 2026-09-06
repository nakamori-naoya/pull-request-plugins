#!/usr/bin/env bash
# Scenario: repositoryのplugin集合、manifest、marketplace、構文が一致する
set -uo pipefail
# 検査は素の環境から始める。呼び出した人の開発用mapやtest cacheが混ざると、
# 「実配布物へ解決できている」ことを確かめられない。必要な検査だけが自分で設定する。
unset HARNESS_PLUGIN_DEV_ROOTS HARNESS_PLUGIN_CACHE_ROOT
# **runtimeを開発環境から拾わせない。** resolverはHARNESS_PLUGIN_RUNTIMEが無いと
# CLAUDE_PLUGIN_ROOT / CODEX_HOME や利用者のinstalled-cacheからruntimeを推測する。
# 手元にそれらがあると通り、何も入っていないCI runnerでは
# dependency-runtime-unresolved で落ちる。**検査するruntimeはここで明示する。**
# 両runtimeを見るprobeは、その場で自分のHARNESS_PLUGIN_RUNTIMEを渡して上書きする。
unset CLAUDE_PLUGIN_ROOT CODEX_HOME CLAUDE_PLUGIN_CACHE CODEX_PLUGIN_CACHE
export HARNESS_PLUGIN_RUNTIME=codex
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/plugin-repository-validation.XXXXXX") || exit 2
trap 'rm -rf "$TMP_ROOT"' EXIT
failed=0
python3 "$ROOT/scripts/test-hardening.py" || failed=1
python3 "$ROOT/scripts/sync-runtime.py" --check || failed=1
# 複製が正本と一致することを、正本そのものに対して確かめる。**兄弟が無ければ失敗させる。**
RUNTIME_SOURCE="${HARNESS_RUNTIME_SOURCE:-$ROOT/../product-planning-plugins/shared/runtime-source}"
if [ ! -d "$RUNTIME_SOURCE" ]; then
  echo "[validate] runtime正本が無い: ${RUNTIME_SOURCE}（HARNESS_RUNTIME_SOURCE で指定する）" >&2
  failed=1
else
  python3 "$ROOT/scripts/sync-runtime.py" --check --source "$RUNTIME_SOURCE" \
    || { echo '[validate] runtime複製が正本とずれている' >&2; failed=1; }
fi
python3 -m unittest discover -s "$ROOT/tests" -p test_verification_cli.py || failed=1


validate_dependency_resolution_contract() {
  local fixture="$TMP_ROOT/dependency-resolution"
  local status=0
  local out

  # (1) 同じrepositoryの内部pluginは、実物のplaybook rootから repository として解決する。
  local pull="$ROOT/plugins/playbooks/pull-request/pull-request"
  local runtime
  for runtime in codex claude; do
    out=$(HARNESS_PLUGIN_RUNTIME="$runtime" python3 "$pull/scripts/resolve-dependency.py" \
      --plugin-root "$pull" --plugin pr-create --marketplace pull-request 2> "$fixture-repo-$runtime.err") || status=1
    jq -e --arg runtime "$runtime" '
      .runtime==$runtime and .plugin=="pr-create" and .source_kind=="repository" and
      .dependency_scope=="internal" and .contract=="pull-request/pr-create"' >/dev/null <<<"$out" || status=1
  done

  # 呼び出し元 bundle を1つ作る。**resolverは所属package宣言の中からしか呼べない。**
  local caller="$fixture/consumer/plugins/playbooks/caller"
  # test cache root は呼び出し元 plugin root の直下だけを許される。
  local cache="$fixture/consumer/plugins/playbooks/caller/.harness-plugin-test-cache"
  mkdir -p "$caller/scripts" "$caller/.claude-plugin" "$caller/.codex-plugin" \
           "$fixture/consumer/plugins/.claude-plugin" "$fixture/consumer/plugins/.codex-plugin" \
           "$fixture/repo" "$cache"
  git -C "$fixture/repo" init -q
  cp "$ROOT/shared/playbook/resolve-dependency.py" "$caller/scripts/resolve-dependency.py"
  cp "$ROOT/shared/playbook/resolve.sh" "$caller/scripts/resolve.sh"
  cp "$ROOT/shared/playbook/state.py" "$caller/scripts/state.py"
  cp "$ROOT/shared/prepare.sh" "$caller/scripts/prepare.sh"
  cp "$ROOT/shared/run-config.py" "$caller/scripts/run-config.py"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$caller/scripts/validate-config.sh"
  chmod 755 "$caller/scripts"/*
  printf -- '---\nname: caller\ndescription: fixture\n---\nfixture\n' > "$caller/SKILL.md"
  for runtime in claude codex; do
    printf '%s\n' '{"name":"caller","version":"1.0.0","description":"fixture","skills":"./","metadata":{"harness":{"contractVersion":1}}}' \
      > "$caller/.${runtime}-plugin/plugin.json"
    printf '%s\n' '{"name":"caller","version":"1.0.0","description":"fixture","skills":["./playbooks/caller"],"metadata":{"harness":{"installationSurface":"playbook-package","marketplace":"caller-market","entryRoot":"./playbooks/caller","playbooks":{"caller":"./playbooks/caller"},"internalPlugins":{},"contractVersion":1,"implements":[{"id":"caller-market/caller","version":1,"kind":"playbook","playbook":"caller"}]}}}' \
      > "$fixture/consumer/plugins/.${runtime}-plugin/plugin.json"
  done
  local caller_root
  caller_root=$(cd "$caller" && pwd -P)

  # provider fixture は、公開playbook packageと同じ形で作る。**bare manifestで通さない。**
  make_provider_fixture() { # make_provider_fixture <package root> <version>
    local package="$1" version="$2" entry="$1/playbooks/fixture"
    mkdir -p "$entry/scripts" "$entry/.claude-plugin" "$entry/.codex-plugin" \
             "$package/.claude-plugin" "$package/.codex-plugin"
    cp "$ROOT/shared/playbook/resolve.sh" "$entry/scripts/resolve.sh"
    cp "$ROOT/shared/playbook/resolve-dependency.py" "$entry/scripts/resolve-dependency.py"
    cp "$ROOT/shared/playbook/state.py" "$entry/scripts/state.py"
    cp "$ROOT/shared/prepare.sh" "$entry/scripts/prepare.sh"
    cp "$ROOT/shared/run-config.py" "$entry/scripts/run-config.py"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$entry/scripts/validate-config.sh"
    chmod 755 "$entry/scripts"/*
    printf -- '---\nname: fixture-skill\ndescription: fixture\n---\nfixture\n' > "$entry/SKILL.md"
    printf '%s\n' 'version: 2' 'name: fixture' 'description: fixture' 'instructions:' \
      '  execution: {directive: fixture}' 'requires:' \
      '  - {plugin: fixture-inner, marketplace: fixture-market}' 'steps:' \
      '  - {id: run, purpose: fixture, skill: fixture-inner-skill}' > "$entry/playbook.yml"
    mkdir -p "$package/skills/inner/.claude-plugin" "$package/skills/inner/.codex-plugin"
    printf -- '---\nname: fixture-inner-skill\ndescription: fixture\n---\nfixture\n' > "$package/skills/inner/SKILL.md"
    local runtime
    for runtime in claude codex; do
      printf '{"name":"fixture-plugin","version":"%s","description":"fixture","skills":["./playbooks/fixture"],"metadata":{"harness":{"installationSurface":"playbook-package","marketplace":"fixture-market","entryRoot":"./playbooks/fixture","playbooks":{"fixture":"./playbooks/fixture"},"internalPlugins":{"fixture-inner":"./skills/inner"},"contractVersion":1,"implements":[{"id":"fixture-market/fixture-plugin","version":1,"kind":"playbook","playbook":"fixture"}]}}}\n' \
        "$version" > "$package/.${runtime}-plugin/plugin.json"
      printf '{"name":"fixture","version":"%s","description":"fixture","skills":"./","metadata":{"harness":{"contractVersion":1}}}\n' \
        "$version" > "$entry/.${runtime}-plugin/plugin.json"
      printf '{"name":"fixture-inner","version":"%s","description":"fixture","skills":"./","metadata":{"harness":{"contractVersion":1}}}\n' \
        "$version" > "$package/skills/inner/.${runtime}-plugin/plugin.json"
    done
  }

  # (2) installed-cache から最も高いsemverを採る。
  local version
  for version in 1.0.0 9.9.9; do
    make_provider_fixture "$cache/fixture-market/fixture-plugin/$version" "$version"
  done
  for runtime in codex claude; do
    out=$(HARNESS_PLUGIN_RUNTIME="$runtime" HARNESS_PLUGIN_CACHE_ROOT="$cache" \
      python3 "$caller/scripts/resolve-dependency.py" --plugin-root "$caller_root" \
      --plugin fixture-plugin --marketplace fixture-market 2> "$fixture/cache-$runtime.err") || status=1
    jq -e --arg runtime "$runtime" '
      .runtime==$runtime and .version=="9.9.9" and .source_kind=="installed-cache" and
      .dependency_scope=="external"' >/dev/null <<<"$out" || status=1
  done

  # (3) dev-map が installed-cache より優先する。
  make_provider_fixture "$fixture/dev" 3.4.5
  jq -n --arg root "$(cd "$fixture/dev" && pwd -P)" '{schema:1,dependencies:{"fixture-market/fixture-plugin":$root}}' > "$fixture/dev-map.json"
  out=$(HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_DEV_ROOTS="$fixture/dev-map.json" HARNESS_PLUGIN_CACHE_ROOT="$cache" \
    python3 "$caller/scripts/resolve-dependency.py" --plugin-root "$caller_root" \
    --plugin fixture-plugin --marketplace fixture-market 2> "$fixture/dev.err") || status=1
  jq -e '.version=="3.4.5" and .source_kind=="dev-map"' >/dev/null <<<"$out" || status=1

  reject_resolution() { # reject_resolution <名前> <期待コード> <環境なしの引数...>
    local name="$1" expected="$2"; shift 2
    if HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" \
       python3 "$caller/scripts/resolve-dependency.py" --plugin-root "$caller_root" "$@" \
       >/dev/null 2> "$fixture/$name.err"; then
      echo "[validate] 解決を拒否できない: $name" >&2
      status=1
    elif ! rg -q "$expected" "$fixture/$name.err"; then
      echo "[validate] 解決を期待した理由で拒否できない: $name ($(head -1 "$fixture/$name.err"))" >&2
      status=1
    fi
  }
  # (4) 見つからない依存。
  reject_resolution missing 'error:dependency-missing.*plugin=missing-plugin.*marketplace=fixture-market' \
    --plugin missing-plugin --marketplace fixture-market
  # (5) manifest identity の食い違い。
  mv "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json" "$fixture/correct-manifest.json"
  jq '.name="other-plugin"' "$fixture/correct-manifest.json" \
    > "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json"
  reject_resolution identity 'manifest-identity-mismatch' --plugin fixture-plugin --marketplace fixture-market
  mv "$fixture/correct-manifest.json" "$cache/fixture-market/fixture-plugin/9.9.9/.codex-plugin/plugin.json"

  # (6) marketplace catalog に同名entryが2つあれば止まる。
  mkdir -p "$fixture/consumer/.agents/plugins"
  jq -n '{name:"fixture-market",plugins:[{name:"fixture-plugin",source:{source:"local",path:"./plugins/a"}},{name:"fixture-plugin",source:{source:"local",path:"./plugins/b"}}]}' \
    > "$fixture/consumer/.agents/plugins/marketplace.json"
  reject_resolution ambiguous 'source_kind=repository reason=marketplace-entry' --plugin fixture-plugin --marketplace fixture-market
  rm -rf "$fixture/consumer/.agents"

  # (7) playbook経路：requires に無いskillを指すstepは止まる。
  playbook_fixture() { # playbook_fixture <requires断片> <step断片>
    { printf '%s\n' 'version: 2' 'name: caller' 'description: fixture' 'instructions:' \
        '  execution: {directive: fixture}' 'requires:'
      printf '%s\n' "$1"
      printf '%s\n' 'steps:' '  - {id: invoke, purpose: fixture, skill: expected-skill}'
    } > "$caller/playbook.yml"
  }
  playbook_fixture '  - {plugin: fixture-plugin, marketplace: fixture-market}'
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" \
     bash "$caller/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/skill.err"; then
    status=1
  else
    rg -q 'steps が指すスキルが requires のプラグインに無い: expected-skill' "$fixture/skill.err" || status=1
  fi
  # (8) requires は {plugin, marketplace} の2キーだけ。version固定も裸文字列も受け付けない。
  playbook_fixture '  - {plugin: fixture-plugin, marketplace: fixture-market, version: 1.0.0}'
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" \
     bash "$caller/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/pin.err"; then status=1; fi
  playbook_fixture '  - fixture-plugin'
  if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME=codex HARNESS_PLUGIN_CACHE_ROOT="$cache" \
     bash "$caller/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/bare.err"; then status=1; fi

  return "$status"
}

validate_publication_delegation_contract() {
  local fixture="$TMP_ROOT/publication-delegation"
  local review_pb="$ROOT/plugins/playbooks/pull-request/pr-review-response"
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
  yq -o=json -I=0 '.' "$review_pb/playbook.yml" > "$fixture/review_pb.json"
  yq -o=json -I=0 '.' "$pull/playbook.yml" > "$fixture/pull.json"
  # 実物playbook自身を固有validatorへ渡す。以後の変異も同じ経路で拒否される。
  bash "$review_pb/scripts/validate-config.sh" "$fixture/review_pb.json" >/dev/null 2>&1 || status=1
  bash "$pull/scripts/validate-config.sh" "$fixture/pull.json" >/dev/null 2>&1 || status=1

  # 実物と同じvalidator経路で各変異を拒否する。
  reject_mutation() { # reject_mutation <validator> <元JSON> <名前> <jq式>
    local validator="$1" source="$2" name="$3" filter="$4"
    jq "$filter" "$source" > "$fixture/$name.json" || { status=1; return; }
    if bash "$validator" "$fixture/$name.json" >/dev/null 2>&1; then
      echo "[validate] 変異を拒否できない: $name" >&2
      status=1
    fi
  }
  # M4b: 外部pluginのscriptを直接実行する形へ戻す変異は拒否する。
  reject_mutation "$review_pb/scripts/validate-config.sh" "$fixture/review_pb.json" m4b \
    '(.steps[] | select(.id=="commit")) |= (.script="scripts/review-gate.py" | .plugin="agent-work-policy" | del(.playbook) | del(.input))'
  # M4c: 1呼び出し1actionを崩す変異（actionを消す・別actionにする）は拒否する。
  reject_mutation "$review_pb/scripts/validate-config.sh" "$fixture/review_pb.json" m4c \
    '(.steps[] | select(.id=="commit")).input.action="merge"'
  reject_mutation "$review_pb/scripts/validate-config.sh" "$fixture/review_pb.json" m4d \
    'del(.steps[] | select(.id=="commit").input)'
  # M5: 公開操作の独自permissionを再導入する変異は拒否する。
  reject_mutation "$review_pb/scripts/validate-config.sh" "$fixture/review_pb.json" m5 '.permissions.commit=true'
  reject_mutation "$review_pb/scripts/validate-config.sh" "$fixture/review_pb.json" m5b '.gates.before_push=true'
  # M6: base/remote/下書き設定をplaybookへ複製する変異は拒否する。
  reject_mutation "$pull/scripts/validate-config.sh" "$fixture/pull.json" m6 \
    '.git={base_branch:"main",remote:"origin"} | .pull_request={draft:false}'
  # M9: 公開操作の委譲を自前scriptへ差し替える変異は拒否する。
  reject_mutation "$pull/scripts/validate-config.sh" "$fixture/pull.json" m9 \
    '(.steps[] | select(.id=="create-pull-request")) |= (.script="scripts/create.sh" | del(.playbook) | del(.input))'
  # M10: 外部rootからpathを組み立てる引数を再導入する変異は拒否する。
  reject_mutation "$pull/scripts/validate-config.sh" "$fixture/pull.json" m10 \
    '(.steps[] | select(.id=="prepare-pull-request")).arguments=["--root=${.deps[\"agent-work-policy\"].root}"]'

  # M8/M8b/M12: shellとsubprocess list形式の素の公開操作を拒否する。
  mkdir -p "$fixture/plugins"
  printf '%s\n' 'git push origin branch' > "$fixture/plugins/raw.sh"
  printf '%s\n' 'subprocess.run(["gh", "pr", "create", "--fill"])' > "$fixture/plugins/m8b.py"
  printf '%s\n' 'subprocess.run(["git", "push"])' > "$fixture/plugins/m12.py"
  has_raw_publication_operation "$fixture/plugins" || status=1

  return "$status"
}

# 実配布物の provider package を指す。sibling checkout を既定にし、環境変数で差し替えられる。
AWP_PACKAGE="${HARNESS_AWP_PACKAGE:-$ROOT/../agent-work-policy-plugins/plugins}"
WRITE_DOC_PACKAGE="${HARNESS_WRITE_DOC_PACKAGE:-$ROOT/../write-doc-plugins/plugins}"

# 実配布物への dev-map を作る。**fixtureだけで緑にしない。**
make_provider_dev_map() { # make_provider_dev_map <出力path>
  local out="$1"
  [ -d "$AWP_PACKAGE" ] || { echo "[validate] 実配布物が無い: ${AWP_PACKAGE}（HARNESS_AWP_PACKAGE で指定する）" >&2; return 1; }
  [ -d "$WRITE_DOC_PACKAGE" ] || { echo "[validate] 実配布物が無い: ${WRITE_DOC_PACKAGE}（HARNESS_WRITE_DOC_PACKAGE で指定する）" >&2; return 1; }
  jq -n --arg awp "$(cd "$AWP_PACKAGE" && pwd -P)" --arg doc "$(cd "$WRITE_DOC_PACKAGE" && pwd -P)" \
    '{schema:1,dependencies:{"agent-work-policy/agent-work-policy":$awp,"write-doc/write-doc":$doc}}' > "$out"
}

# 消費側の文書・設定・scriptに外部依存の内部の作りが漏れていないかを静的に見る。
validate_consumer_contract_lint() {
  local fixture="$TMP_ROOT/consumer-lint"
  local status=0
  mkdir -p "$fixture"
  make_provider_dev_map "$fixture/dev-roots.json" || return 1
  for runtime in claude codex; do
    HARNESS_PLUGIN_DEV_ROOTS="$fixture/dev-roots.json" \
      python3 "$ROOT/scripts/lint-consumer-contract.py" --repo "$ROOT" --runtime "$runtime" || status=1
  done
  return "$status"
}

# 実際に配布されている provider package に対して、両runtimeで解決する。
validate_real_distribution_resolution() {
  local fixture="$TMP_ROOT/real-distribution"
  local status=0
  mkdir -p "$fixture/repo"
  git -C "$fixture/repo" init -q
  make_provider_dev_map "$fixture/dev-roots.json" || return 1
  local playbook
  for playbook in pull-request pr-review-response; do
    local root="$ROOT/plugins/playbooks/pull-request/$playbook"
    local runtime
    for runtime in claude codex; do
      if ! XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_RUNTIME="$runtime" \
           HARNESS_PLUGIN_DEV_ROOTS="$fixture/dev-roots.json" \
           bash "$root/scripts/resolve.sh" "$fixture/repo" > "$fixture/$playbook-$runtime.yml" 2> "$fixture/$playbook-$runtime.err"; then
        echo "[validate] 実配布物に対して解決できない: $playbook ($runtime) $(head -3 "$fixture/$playbook-$runtime.err")" >&2
        status=1
        continue
      fi
      yq -o=json -I=0 '.' "$fixture/$playbook-$runtime.yml" > "$fixture/$playbook-$runtime.json"
      # 外部依存は2つだけで、どちらも契約を自己宣言した公開playbookである。
      jq -e '
        (.deps | to_entries | map(select(.value.dependency_scope=="external")) | map(.key) | sort)
          ==["agent-work-policy","write-doc"] and
        .deps["agent-work-policy"].contract=="agent-work-policy/agent-work-policy" and
        .deps["write-doc"].contract=="write-doc/write-doc" and
        (.deps["agent-work-policy"].implements
          | map(select(.id=="agent-work-policy/agent-work-policy" and .version==1 and .kind=="playbook"))
          | length==1) and
        (.deps["write-doc"].implements
          | map(select(.id=="write-doc/write-doc" and .version==1 and .kind=="playbook"))
          | length==1) and
        # 入口は entry で指す。skill名で指す形は公開面に無い。
        (.deps["agent-work-policy"].entry|type=="string" and endswith("/SKILL.md")) and
        (.deps["write-doc"].entry|type=="string" and endswith("/SKILL.md")) and
        (.deps["agent-work-policy"].entry_skill|type=="string") and
        # read-only の照会を含め、実配布物が宣言する動作を要求している。
        (.deps["agent-work-policy"].implements[0].actions|length==10) and
        (.deps["agent-work-policy"].implements[0].actions|index("inspect")!=null) and
        (.resolution.bindings_lock|type=="string" and startswith("/")) and
        # 外部依存を skill: / script: で掴んでいない。
        all(.playbook.steps[]; (.plugin // "") as $p | $p!="agent-work-policy" and $p!="write-doc") and
        # 委譲は1呼び出し1action。宣言されたactionだけを要求する。
        ([.playbook.steps[] | select(.playbook=="agent-work-policy") | .input.action] | length>0) and
        ([.playbook.steps[] | select(.playbook=="agent-work-policy") | .input.action]
          - (.deps["agent-work-policy"].implements[0].actions) | length==0)
      ' "$fixture/$playbook-$runtime.json" >/dev/null \
        || { echo "[validate] 実配布物への解決結果が契約どおりでない: $playbook ($runtime)" >&2; status=1; }
      # 公開面の4点が実在する。
      local dep member
      for dep in agent-work-policy write-doc; do
        local dep_root dep_entry
        dep_root=$(jq -r --arg d "$dep" '.deps[$d].root' "$fixture/$playbook-$runtime.json")
        for member in playbook.yml scripts/resolve.sh scripts/prepare.sh; do
          [ -f "$dep_root/$member" ] || { echo "[validate] 公開面の入口が無い: $dep/$member" >&2; status=1; }
        done
        dep_entry=$(jq -r --arg d "$dep" '.deps[$d].entry' "$fixture/$playbook-$runtime.json")
        [ -f "$dep_entry" ] || { echo "[validate] 公開playbook入口のSKILL.mdが無い: $dep" >&2; status=1; }
      done
    done
  done
  return "$status"
}

# 最上位規則（外部pluginの公開面はplaybook 1枚だけ）を、実配布物に対して機械的に確かめる。
validate_external_dependency_rules() {
  local fixture="$TMP_ROOT/external-rules"
  local probe="$fixture/consumer/plugins/playbooks/probe/probe"
  local status=0
  mkdir -p "$probe/scripts" "$probe/.claude-plugin" "$probe/.codex-plugin" \
           "$fixture/consumer/plugins/.claude-plugin" "$fixture/consumer/plugins/.codex-plugin" "$fixture/repo"
  git -C "$fixture/repo" init -q
  make_provider_dev_map "$fixture/dev-roots.json" || return 1
  cp "$ROOT/shared/prepare.sh" "$probe/scripts/prepare.sh"
  cp "$ROOT/shared/run-config.py" "$probe/scripts/run-config.py"
  cp "$ROOT/shared/playbook/resolve.sh" "$probe/scripts/resolve.sh"
  cp "$ROOT/shared/playbook/resolve-dependency.py" "$probe/scripts/resolve-dependency.py"
  cp "$ROOT/shared/playbook/state.py" "$probe/scripts/state.py"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$probe/scripts/validate-config.sh"
  chmod 755 "$probe/scripts"/*
  printf -- '---\nname: probe\ndescription: fixture\n---\nfixture\n' > "$probe/SKILL.md"
  local runtime
  for runtime in claude codex; do
    printf '%s\n' '{"name":"probe","version":"1.0.0","description":"fixture","skills":"./","metadata":{"harness":{"contractVersion":1}}}' \
      > "$probe/.${runtime}-plugin/plugin.json"
    printf '%s\n' '{"name":"probe","version":"1.0.0","description":"fixture","skills":["./playbooks/probe/probe"],"metadata":{"harness":{"installationSurface":"playbook-package","marketplace":"probe","entryRoot":"./playbooks/probe/probe","playbooks":{"probe":"./playbooks/probe/probe"},"internalPlugins":{},"contractVersion":1,"implements":[{"id":"probe/probe","version":1,"kind":"playbook","playbook":"probe"}]}}}' \
      > "$fixture/consumer/plugins/.${runtime}-plugin/plugin.json"
  done
  probe_playbook() { # probe_playbook <step本体のYAML断片>
    { printf '%s\n' 'version: 2' 'name: probe' 'description: fixture' 'instructions:' \
        '  execution: {directive: fixture}' 'requires:' \
        '  - {plugin: agent-work-policy, marketplace: agent-work-policy}' 'steps:' \
        '  - id: delegate' '    purpose: fixture'
      printf '%s\n' "$1"
    } > "$probe/playbook.yml"
  }
  probe_reject() { # probe_reject <名前> <期待コード>
    if XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_DEV_ROOTS="$fixture/dev-roots.json" \
       bash "$probe/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/$1.err"; then
      echo "[validate] 規則違反を拒否できない: $1" >&2
      status=1
    elif ! rg -q "$2" "$fixture/$1.err"; then
      echo "[validate] 規則違反を期待した理由で拒否できない: $1 ($(head -1 "$fixture/$1.err"))" >&2
      status=1
    fi
  }
  # (a) 適合形は通る。実配布物の公開playbookをplaybook: stepとして解決できる。
  probe_playbook '    playbook: agent-work-policy
    input: {action: commit}'
  if ! XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_DEV_ROOTS="$fixture/dev-roots.json" \
       bash "$probe/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/ok.err"; then
    echo "[validate] 適合形が通らない: $(head -3 "$fixture/ok.err")" >&2
    status=1
  fi
  # (b) 外部依存の script は実行できない。
  probe_playbook '    script: scripts/state.py
    plugin: agent-work-policy'
  probe_reject external-script 'external-dependency-script'
  # (c) 外部依存の公開 skill を skill: で掴めない。
  probe_playbook '    skill: work-with-policy'
  probe_reject external-skill 'external-dependency-skill'
  # (d) 外部 root から公開面以外の path を組み立てられない。
  probe_playbook '    playbook: agent-work-policy
    input: {action: commit}
    arguments: ["${.deps[\"agent-work-policy\"].root}/scripts/state.py"]'
  probe_reject external-path 'external-dependency-path'
  # skill名で入口を指す形（`.skills.<名前>`）の拒否は、共通のhardening試験が持つ。
  # ここへ literal を置くと消費側lintがこのfile自身を落とすので、重複させない。
  # (e) 宣言されていない action は要求できない。
  probe_playbook '    playbook: agent-work-policy
    input: {action: rebase-everything}'
  probe_reject unsupported-action 'binding-capability-unsupported'
  # (f) read-only の照会は実配布物が宣言している。
  probe_playbook '    playbook: agent-work-policy
    input: {action: inspect}'
  if ! XDG_CONFIG_HOME="$fixture/config" HARNESS_PLUGIN_DEV_ROOTS="$fixture/dev-roots.json" \
       bash "$probe/scripts/resolve.sh" "$fixture/repo" >/dev/null 2> "$fixture/inspect.err"; then
    echo "[validate] read-onlyの照会を要求できない: $(head -3 "$fixture/inspect.err")" >&2
    status=1
  fi
  return "$status"
}

validate_manifest_identity_contract() {
  local fixture="$TMP_ROOT/manifest-identity"
  local source="$ROOT/plugins/skills/pull-request/pr-create"
  local status=0
  local version
  version=$(jq -r '.version' "$source/.codex-plugin/plugin.json")
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
# package manifest：両runtimeが同一値で、所属marketplaceを自己宣言する。
python3 - "$ROOT/plugins" <<'MANIFEST_PY' || failed=1
import json, sys
from pathlib import Path
package = Path(sys.argv[1])
data = {r: json.loads((package / f'.{r}-plugin/plugin.json').read_text()) for r in ('claude', 'codex')}
harness = {r: d.get('metadata', {}).get('harness', {}) for r, d in data.items()}
errors = []
if harness['claude'] != harness['codex']:
    errors.append('両runtimeのmetadata.harnessが一致しない')
if data['claude'].get('skills') != data['codex'].get('skills'):
    errors.append('両runtimeのskills宣言が一致しない')
h = harness['claude']
if h.get('marketplace') != 'pull-request':
    errors.append('metadata.harness.marketplace が pull-request でない: %r' % h.get('marketplace'))
if h.get('installationSurface') != 'playbook-package':
    errors.append('installationSurface が playbook-package でない')
if sorted(h.get('playbooks', {})) != ['pr-review-response', 'pull-request']:
    errors.append('公開playbookの宣言が違う: %r' % sorted(h.get('playbooks', {})))
if 'pull-request' in (h.get('internalPlugins') or {}):
    errors.append('内部plugin名がmarketplace名と衝突している')
for message in errors:
    print('[validate] ' + message, file=sys.stderr)
raise SystemExit(1 if errors else 0)
MANIFEST_PY
bash "$ROOT/scripts/validate-marketplace.sh" "$ROOT" || failed=1
bash "$ROOT/scripts/test-marketplace-validation.sh" || failed=1
while IFS= read -r pb; do
  yq -o=json -I=0 '.' "$pb" | jq -e '.version==2 and (.requires|length>0) and all(.requires[]; type=="object" and ((keys|sort)==["marketplace","plugin"]))' >/dev/null || failed=1
  yq -o=json -I=0 '.' "$pb" | jq -e 'all(.requires[]; .marketplace=="pull-request" or .plugin==.marketplace)' >/dev/null || failed=1
  root=$(dirname "$pb")
  cmp -s "$ROOT/shared/playbook/resolve.sh" "$root/scripts/resolve.sh" || failed=1
  cmp -s "$ROOT/shared/playbook/resolve-dependency.py" "$root/scripts/resolve-dependency.py" || failed=1
  cmp -s "$ROOT/shared/playbook/state.py" "$root/scripts/state.py" || failed=1
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
validate_real_distribution_resolution || failed=1
validate_external_dependency_rules || failed=1
validate_consumer_contract_lint || failed=1
validate_manifest_identity_contract || failed=1
if [ "$failed" -eq 0 ]; then echo 'Validation: passed'; else echo 'Validation: failed'; fi
[ "$failed" -eq 0 ]
