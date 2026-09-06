---
name: respond-to-pr-review
description: 指定GitHub PRのreview commentを取得・評価し、人間gateで採否を確認して、採用分だけを修正・検証する。commit・pushは`agent-work-policy`の公開playbookへ委譲する。reviewへの返信やresolveはしない。
---

# respond-to-pr-review

評価内容はsourceから判断し、工程順、操作許可、人間介入点は設定から変えない。

## 0. プラグイン root を決める

<!-- BEGIN shared:skill-entry/root-block -->
```bash
BUNDLE_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
if [ -d "${BUNDLE_ROOT}/playbooks/pull-request/pr-review-response" ]; then
  PLUGIN_ROOT="${BUNDLE_ROOT}/playbooks/pull-request/pr-review-response"
else
  PLUGIN_ROOT="${BUNDLE_ROOT}"
fi
```

`PLUGIN_ROOT`は配布物rootの絶対パスである。単一skill pluginではこの`SKILL.md`があるdirectory、複数skill pluginでは`skills/<skill>/`の2つ上に当たる。Claude Codeでは`${CLAUDE_PLUGIN_ROOT}`が自動展開される。
<!-- END shared:skill-entry/root-block -->

## 1. 工程を解決する

<!-- BEGIN shared:skill-entry/config-load -->
```bash
CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)") || exit 2
```

**このコマンドは説明例ではない。必ず実行する。** 解決済みYAMLが空なら先へ進まない。設定ファイルを直接読んで代用しない。

本文中の `${...}` は解決済みYAMLのプロパティである。使用時に `yq -er` で読み、欠落または `null` なら停止する。
<!-- END shared:skill-entry/config-load -->

`${.instructions.execution.directive}`に従い`${.playbook.steps}`を上から実行する。`${.playbook.permissions}`と`${.playbook.gates}`はreview取込・修正だけに使う。公開Git操作のpermission、human gate、検証、実行は`playbook:`工程として委譲する。

**自分のpackageの工程（`skill:` と `script:`）を呼ぶときは `--scope=${.resolution.scope_root}` を必ず渡す。**この段取りを通るときだけ効く設定がそこにある。渡さなければ効かない。入れ子の段取りへは、受け取ったものをそのまま渡す（自分の名前で作り直さない）。

公開方針はrepository単位で一つである。公開Git操作の委譲へは`--scope`を渡さず、scope設定で公開permissionやhuman gateを差し替えない。

## 2. 評価する

`review-gate.py preflight`でrepositoryと開始時worktreeを検査する。review取込前に`review-gate.py permission review_import`を通し、`assess-pr-review`を呼ぶ。評価成果を提示する。

`after_assessment` gateを通す。acceptが0件なら変更せず報告して終了する。

## 3. 採用分だけ修正する

`modify` permissionと`before_modify` gateを通し、`apply-pr-review`を呼ぶ。

差分と変更fileを提示し、`after_modify` gateを通す。評価でacceptされていない変更が混ざったら先へ進まない。

## 4. 検証し、公開操作を委譲する

`verify-pr-review`を呼ぶ。失敗したらcommitしない。

設定された時点でreportが有効なら資料化の段取りを呼び、その成果物を後続工程へ渡す。

commitとpushは、それぞれ**1呼び出し1操作**として`agent-work-policy`の公開playbookへ委譲する。**呼び出しは2段で、`prepare.sh` は1回だけ実行する。**契約が定める入力YAMLを一時領域へ書き、自分で実行設定を解決する。

```bash
POLICY_CFG=$(bash "${.deps.agent-work-policy.root}/scripts/prepare.sh" "$(pwd)" \
  --input="$INPUT_FILE" --bindings="${.resolution.bindings_lock}") || exit 2
```

そのうえで `${.deps.agent-work-policy.entry}`（公開playbook入口の`SKILL.md`の絶対path）の手順に、いま得た `$POLICY_CFG` を渡して実行し、入力に書いた書き込み先から公開出力を読む。委譲先は `prepare.sh` を実行し直さない。**委譲先の中のscript、引数、exit code、設定キーは扱わない。** `entry_skill` は表示用であり、その名前で分岐しない。

出力が承認待ちを示した場合だけ、同じ出力に含まれる承認対象を提示し、実際に承認を得てから同じ操作を承認済みとして呼び直す。公開操作のための独自permission・gate・`git`・`gh`は追加しない。

review固有のcommandとgateの呼び方、委譲の手順は[実行契約](references/workflow.md)に従う。公開操作の入力・出力・保証は委譲先が公開する契約を正本とする。

## 5. 報告する

PR、comment別採否、変更file、検証結果、commit、push先を報告する。未承認・未実行を成功扱いせず、reviewへの返信・thread resolveはしない。

設定生成で返却された絶対pathを実行記録へ残す。別shellでは記録した絶対pathを `CFG_FILE` へ明示代入して読む。処理が成功・停止・失敗した最後に `python3 "${PLUGIN_ROOT}/scripts/run-config.py" cleanup --config "$CFG_FILE"` でこのrunの設定だけを削除する。別runの設定は削除しない。
