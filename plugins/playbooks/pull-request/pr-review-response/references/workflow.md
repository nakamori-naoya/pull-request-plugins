# 実行契約

このplaybookが自分で判断するのは、review取込と修正だけである。公開Git操作は`playbook:`工程として委譲し、その入口・入力・出力・保証以外には依存しない。

## preflight

```bash
python3 "${PLUGIN_ROOT}/scripts/review-gate.py" preflight --config "$CFG_FILE" --repo "$(pwd)"
```

`${.playbook.git.require_clean_start}`がtrueなら、開始時にtracked/untracked変更が1件でもあれば停止する。

## permission

```bash
python3 "${PLUGIN_ROOT}/scripts/review-gate.py" permission --config "$CFG_FILE" --name review_import
python3 "${PLUGIN_ROOT}/scripts/review-gate.py" permission --config "$CFG_FILE" --name modify
```

許可はexit 0、禁止はexit 3。禁止を承認質問で上書きしない。

## gate

```bash
python3 "${PLUGIN_ROOT}/scripts/review-gate.py" gate --config "$CFG_FILE" --name after_assessment
# requiredなら人間へ確認し、明示承認後だけ:
python3 "${PLUGIN_ROOT}/scripts/review-gate.py" gate --config "$CFG_FILE" --name after_assessment --approved
```

`before_modify`、`after_modify`も同じ。required未承認はexit 3。

## 公開Git操作の委譲

`commit`と`push`は、`agent-work-policy`の公開playbookへ**1呼び出し1操作**で委譲する。`${.deps.<論理依存名>}` から組み立ててよいのは `.root` の直下3点（`scripts/prepare.sh`、`playbook.yml`、`scripts/resolve.sh`）と、入口`SKILL.md`の絶対pathである `.entry` だけである。

**呼び出しは2段で、`prepare.sh` は1回だけ実行する。**委譲先の契約が定める入力YAMLを一時領域へ書き、自分で実行設定を解決してから、そのpathを入口`SKILL.md`へ渡す。その action が使わないキーは入力に書かない。

```bash
cat > "$INPUT_FILE" <<YML
contract: agent-work-policy/agent-work-policy
version: 1
action: commit                       # push の工程では push
repo: $(pwd)
paths: [<repository相対path>, ...]   # commit のときだけ
message: <${.playbook.git.commit_message} の値>
output_to: $OUTPUT_FILE
YML

POLICY_CFG=$(bash "${.deps.agent-work-policy.root}/scripts/prepare.sh" "$(pwd)" \
  --input="$INPUT_FILE" --bindings="${.resolution.bindings_lock}") || exit 2
```

そのうえで `${.deps.agent-work-policy.entry}`（公開playbook入口の `SKILL.md` の絶対path）の手順に、いま得た `$POLICY_CFG` を渡して実行し、`output_to` に書かれた公開出力だけを読む。委譲先は `prepare.sh` を実行し直さない。実行し直させると、渡した入力・scope・束縛が捨てられる。**委譲先の中の工程名、script、引数、exit code、設定ファイル、設定キーは扱わない。** `entry_skill` は表示用であり、その名前で分岐しない。

公開方針はrepository単位で一つであり、呼び出し元scopeで差し替えられないよう、この委譲へは`--scope`を意図的に渡さない。

### 承認待ち

出力が承認待ちを示したときは、同じ出力に含まれる承認対象（何が、どこへ向かうか、詳細のpath）をそのまま利用者へ提示する。**実際に承認を得たときだけ**、同じ操作の入力に承認済みを明示して呼び直す。承認が得られなければ、その操作を実行済みとして扱わない。permissionそのものの拒否は承認質問へ変えない。

## report

`report.enabled: false`なら資料工程をすべてskipする。trueなら`requires`に`write-doc`が必要で、`report.timing`に一致する1工程だけを実行する。資料成果物は直後のgateまたは後続工程の`conditional_needs`で拘束される。

資料化は`write-doc`契約v2として直接委譲する。素材は`[{kind: file, path: <束ねた素材の絶対path>}]`とし、新規作成では`output_directory`と`name`、更新では`update_target`を`${.deps.write-doc.entry}`へ直接渡す。保存先が無ければ推測せず停止する。結果の`status`と、成功時の`path`または失敗時の`reason`を直接受け取り、中間YAML、`output_to`、write-doc用の`prepare.sh`は使わない。

## 実行設定の後始末

呼出元の`CFG_FILE`と、`agent-work-policy`への委譲のために自分が作った解決済みYAMLは、自分で片付ける。`write-doc`には実行設定がない。委譲先が内部で作った実行設定は委譲先自身が片付ける。**互いに代行しない。**
