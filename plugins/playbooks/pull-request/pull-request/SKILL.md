---
name: open-pull-request
description: Gitの作業branchとbase branchの競合を検出し、現行実装、関連する過去の修正・commit・GitHub PRから意図を理解して解消・検証した後、Pull Requestを作成する。「コンフリクトを解消してPRを作って」「PRを作成して」と言われたときに使う。競合資料は設定により解消前の提案または解消後の実績として提示する。
---

# open-pull-request

競合解消とPR作成を、設定された資料提示時点とrepositoryの公開規則を保って完了する。

## 0. plugin rootを決める

<!-- BEGIN shared:skill-entry/root-block -->
```bash
BUNDLE_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
if [ -d "${BUNDLE_ROOT}/playbooks/pull-request/pull-request" ]; then
  PLUGIN_ROOT="${BUNDLE_ROOT}/playbooks/pull-request/pull-request"
else
  PLUGIN_ROOT="${BUNDLE_ROOT}"
fi
```

`PLUGIN_ROOT`は配布物rootの絶対パスである。単一skill pluginではこの`SKILL.md`があるdirectory、複数skill pluginでは`skills/<skill>/`の2つ上に当たる。Claude Codeでは`${CLAUDE_PLUGIN_ROOT}`が自動展開される。
<!-- END shared:skill-entry/root-block -->

## 1. 工程と選択を解決する

<!-- BEGIN shared:skill-entry/config-load -->
```bash
CFG_FILE=$(bash "${PLUGIN_ROOT}/scripts/prepare.sh" "$(pwd)") || exit 2
```

**このコマンドは説明例ではない。必ず実行する。** 解決済みYAMLが空なら先へ進まない。設定ファイルを直接読んで代用しない。

本文中の `${...}` は解決済みYAMLのプロパティである。使用時に `yq -er` で読み、欠落または `null` なら停止する。
<!-- END shared:skill-entry/config-load -->

`${.instructions.execution.directive}`に従い、`${.playbook.steps}`を上から実行する。`${.playbook.conflict_report.timing}`と`${.playbook.verification.commands}`は使用時に読む。

自分のpackageの工程（`skill:` と `script:`）へは`--scope=${.resolution.scope_root}`を渡す。入れ子の段取りへは受け取ったscopeを作り直さずそのまま渡す。

## 2. 入れ子の段取りを呼ぶ

`playbook:` の工程は、依存先が公開している入口だけで実行する。依存先の中の工程名、script、設定ファイル、設定キーは扱わない。`${.deps.<論理依存名>}` から組み立ててよいのは `${.deps.<論理依存名>.root}` の直下3点（`scripts/prepare.sh`、`playbook.yml`、`scripts/resolve.sh`）と、入口`SKILL.md`の絶対pathである `${.deps.<論理依存名>.entry}` だけである。

**呼び出しは2段で、`prepare.sh` は1回だけ実行する。**

1. その工程の `input` と、依頼から決まる値を、依存先の契約が定める入力YAMLとして一時領域へ書く。出力の書き込み先も入力に含める。**1回の呼び出しで頼む操作は1つだけである。** その action が使わないキーは書かない。
2. **自分で** `prepare.sh` を実行して実行設定を解決する。公開Git操作の工程はこの形で呼ぶ。

```bash
POLICY_CFG=$(bash "${.deps.agent-work-policy.root}/scripts/prepare.sh" "$(pwd)" \
  --input="$INPUT_FILE" --bindings="${.resolution.bindings_lock}") || exit 2
```

資料化の工程はこの形で呼ぶ。素材は自分で束ねたファイルの絶対pathで渡し、出力の書き込み先も入力に書く。

```bash
cat > "$INPUT_FILE" <<YML
contract: write-doc/write-doc
version: 1
material: [<束ねた素材の絶対path>]
name: <ファイル名>
output_to: $OUTPUT_FILE
YML

DOC_CFG=$(bash "${.deps.write-doc.root}/scripts/prepare.sh" "$(pwd)" \
  --input="$INPUT_FILE" --scope="${.resolution.scope_root}" \
  --bindings="${.resolution.bindings_lock}") || exit 2
```

既存の資料を差し替えるときは `name` を書かず、代わりに `update_target` を書く。両方は書けない。`output_directory` は任意で、省略すれば利用者の設定で決まる。

3. `${.deps.agent-work-policy.entry}` あるいは `${.deps.write-doc.entry}` が、公開playbook入口の `SKILL.md` の絶対pathである。**その手順に、手順2で得た解決済みYAMLの絶対pathを渡して**実行する。依存先は `prepare.sh` を実行し直さない。実行し直させると、渡した入力・scope・束縛が捨てられる。
4. 入力に書いた書き込み先から公開出力を読む。**依存先の内部の値を読みに行かない。**

`${.deps.<論理依存名>.entry_skill}` は表示用である。**その名前で分岐しない。**

公開Git操作の段取りへは`--scope`を渡さない。scope設定で公開permissionやhuman gateを弱める経路を作らないためである。

自分が `prepare.sh` で作った解決済みYAMLは自分のものなので、自分で片付ける。依存先が内部で作った実行設定は依存先が片付ける。

### 承認待ちの扱い

公開Git操作の工程が承認待ちを返したときは、返ってきた承認対象（何が、どこへ向かうか、詳細のpath）をそのまま利用者へ提示する。**実際に承認を得たときだけ**、同じ工程の入力に承認済みを明示して呼び直す。承認が得られなければ、その操作を実行済みとして扱わない。permissionそのものの拒否は承認質問へ変えない。

## 3. 競合を扱う

最初の工程は**何も変えない照会**である。返ってきた作業場所の値（base branch、remote、下書き設定、作業branch、worktree）と状態（working treeがcleanか、baseがあるか、その作業branchへ開いているPR番号）を、競合調査・解消・PR本文の組み立てへ明示的に渡す。**別のbase/remote/下書き設定を自分で決めない。** これらは公開出力からだけ受け取り、他所から推測しない。

開いているPR番号が `null` のときは「無い」と断定しない。**無いか、確認できなかったかのどちらか**である。PR本文の組み立てでは自分で重複を確認する。

この工程は既存の作業branchでもworking treeが汚れていても停止しない。新しい作業branchを始める判定は、この段取りの責務ではない。

競合調査のSHAと証拠を保持する。競合が無ければ資料作成と解消を飛ばす。

`before_resolution`では、競合、両側の目的、推奨方針、検証案を資料化して利用者へ示す。明示承認を得るまでgateを通さず、解消を始めない。`after_resolution`では事前資料とgateを使わず、解消後に競合、採った方針、実際の修正、検証結果を資料化して示す。

解消工程には調査成果、base、remote、検証commandを渡す。現在SHAまたは競合集合が変わった場合は再調査なしに続けない。

## 4. PRを作成して報告する

競合なし、または解消と全検証が成功した場合だけPR本文の組み立てへ進む。組み立てたtitleとbody fileを、pushとPR作成の工程へ入力として渡す。

下書きPRをレビュー受付へ遷移するのは、利用者またはmanagerが内部レビュー完了を明示した後の最後の工程だけである。PR作成直後に無条件で遷移しない。

PR URLとnumber、head/base、競合の有無、資料の提示時点とpath、解消方針、検証結果、公開Git操作の結果と承認待ち・停止・未確認事項を報告する。

設定生成で返却された絶対pathを実行記録へ残す。別shellでは記録した絶対pathを `CFG_FILE` へ明示代入して読む。処理が成功・停止・失敗した最後に `python3 "${PLUGIN_ROOT}/scripts/run-config.py" cleanup --config "$CFG_FILE"` でこのrunの設定だけを削除する。別runの設定は削除しない。入れ子の段取りが作った実行設定は、その段取り自身が片付ける。**呼び出し元が代行しない。**
