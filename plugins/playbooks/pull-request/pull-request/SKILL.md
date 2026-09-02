---
name: open-pull-request
description: Gitの作業branchとbase branchの競合を検出し、現行実装、関連する過去の修正・commit・GitHub PRから意図を理解して解消・検証した後、Pull Requestを作成する。「コンフリクトを解消してPRを作って」「PRを作成して」と言われたときに使う。競合資料は設定により解消前の提案または解消後の実績として提示する。
---

# open-pull-request

競合解消とPR作成を、設定された資料提示時点とrepositoryの公開規則を保って完了する。

下書きPRを内部レビュー完了後にレビュー受付へ遷移する責務は、この`open-pull-request`工程には含めない。明示入力でその遷移だけを行う同一pluginの第2入口`mark-ready-for-review`を使う。

## 0. plugin rootを決める

<!-- BEGIN shared:skill-entry/root-block -->
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
```

`PLUGIN_ROOT`は配布物rootの絶対パスである。単一skill pluginではこの`SKILL.md`があるdirectory、複数skill pluginでは`skills/<skill>/`の2つ上に当たる。Claude Codeでは`${CLAUDE_PLUGIN_ROOT}`が自動展開される。
<!-- END shared:skill-entry/root-block -->

## 1. 工程と選択を解決する

<!-- BEGIN shared:skill-entry/config-load -->
```bash
CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)") || exit 2
trap 'rm -f "$CFG_FILE"' EXIT
```

**このコマンドは説明例ではない。必ず実行する。** 解決済みYAMLが空なら先へ進まない。設定ファイルを直接読んで代用しない。

本文中の `${...}` は解決済みYAMLのプロパティである。使用時に `yq -er` で読み、欠落または `null` なら停止する。
<!-- END shared:skill-entry/config-load -->

`${.instructions.execution.directive}`に従い、`${.playbook.steps}`を上から実行する。`${.playbook.conflict_report.timing}`と`${.playbook.verification.commands}`は使用時に読む。公開Git操作の設定と実行はAgent Work Policyへ委譲し、このplaybookの設定からは読まない。

`${.deps["agent-work-policy"].root}`を唯一の`POLICY_ROOT`として受け取り、`bash "$POLICY_ROOT/scripts/prepare.sh" "$(pwd)"`で公開方針を解決する。そこで得た`${.workspace.base_branch}`、`${.git.remote}`、`${.pull_request.draft}`を競合調査・解消・PR作成へ明示的に渡す。`create-pull-request`には同じ`POLICY_ROOT`を`--policy-root`として渡す。依存cacheのpath推測、下流側での設定再解決、別のbase/remote/draftの指定はしない。

公開方針はrepository単位で一つである。上記のAgent Work Policy `prepare.sh`へ`--scope`は渡さない。scope設定で公開permissionやhuman gateを弱める経路を作らないためである。

各工程へ`--scope=${.resolution.scope_root}`を渡す。入れ子の段取りへは受け取ったscopeを作り直さずそのまま渡す。

## 2. 競合を扱う

競合調査のSHAと証拠を保持する。競合が無ければ資料作成と解消を飛ばす。競合調査だけを行う場合も、baseとremoteの出所を単一に保つためAgent Work Policyの設定解決が必要である。

`before_resolution`では、競合、両側の目的、推奨方針、検証案を資料化して利用者へ示す。明示承認を得るまでgateを通さず、解消を始めない。`after_resolution`では事前資料とgateを使わず、解消後に競合、採った方針、実際の修正、検証結果を資料化して示す。

解消工程には調査成果、base、remote、検証commandを渡す。現在SHAまたは競合集合が変わった場合は再調査なしに続けない。

## 3. PRを作成して報告する

競合なし、または解消と全検証が成功した場合だけPR作成工程へ進む。title、body、AWP設定から得たdraft、base、remote、`--policy-root="$POLICY_ROOT"`と、競合があった場合は解消結果と資料参照を渡す。

PR URLとnumber、head/base、競合の有無、資料の提示時点とpath、解消方針、検証結果、Agent Work Policyが返したpush・draft・停止・未確認事項を報告する。
