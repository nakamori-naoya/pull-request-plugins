---
name: resolve-pr-conflicts
description: 指定したGitの作業branch（またはそのPR）とbase branchの競合を非破壊で調査し、現行実装、関連する過去の修正・commit・GitHub PRから両側の意図を復元して資料化し、repository設定が定める時点の人間gateを経て意味を保って解消し、設定の検証commandを全件通す。「このbranchの競合を調べて解消して」「PRの競合を意図に基づいて解いて」「競合の両側の目的を説明して」と言われたときに使う。Pull Requestの作成、push、review対応はしない。競合が無ければ検出方法を添えてそう報告して終える。
---

# resolve-pr-conflicts

作業branchとbase branchの競合を、両側の目的を復元したうえで意味を保って解消し、検証済みの状態にする。競合資料を解消前の提案として示すか解消後の実績として示すかと、解消後に通す検証commandは、repositoryの設定fileが持つ。作業場所の照会は `agent-work-policy` の公開契約で行い、資料化は `write-doc` の公開契約で行う。公開Git操作（push、PR作成）はこの入口の仕事ではない。

## 入力

- `repository_path`: 対象repositoryの絶対path。
- `user_input`: 対象のbranchまたはPR、base branch（省略時は照会結果のbase）、依頼の目的。
- `document_destination`: 競合があり資料を作る時点で使う任意入力。新規作成なら `{output_directory: <既存の書き込み可能な絶対directory>, name: <.md名>}`、更新なら `{update_target: <既存Markdownの絶対path>}` のどちらか一方だけを持つobject。競合が無ければ未使用の保存先を質問・検査しない。
- `references`: 追加で従う資料の絶対path配列。任意。手順の最初に読み、以降の判断でこの規約と併せて従う。
- 設定file: `<repository root>/.harness-plugins/resolve-pr-conflicts.config.yml`。1層で必須。keyは `version: 1`、`conflict_report.timing`（`before_resolution` = 解消前に提案資料を示して承認を待つ / `after_resolution` = 解消後に実績資料を示す）、`verification.commands`（競合解消後にすべて成功させるcommandの配列）。記入例は [`assets/resolve-pr-conflicts.config.example.yml`](assets/resolve-pr-conflicts.config.example.yml)。読み方は手順 1 の `config.py` の契約が定める。

プロジェクト固有の規約（置き場、命名、追加で従う資料）は、対象repositoryのAGENTS.md / CLAUDE.mdと`references`で渡される。この入口は既定値を持たず、指示文へ展開もしない。

同じagentが、同じdirectoryの [`playbook.yml`](playbook.yml) を読み、その `steps` の宣言順を実行順の正式な定義として扱う。`agent_work: invoking_agent` の工程はこのagentが同じ文脈で担う調査・判断・変更・検証、`script:` は決定論的なtool、`playbook:` は外部公開playbookの直接呼び出しである。`when` は設定fileの値と実行時成果で判定し、`conditional_needs` は同じ条件のときだけ増える開始条件である。

## 判断基準

### 作業場所の値は公開出力から受け取ったか

base branch、remote、作業branch、working treeがcleanか、baseがあるかは、`workspace` 工程の `workspace` と `operation_result` からだけ受け取る。`user_input` がbaseを指定していなければ照会結果のbaseを使い、別のbaseを自分で決めない。

### 競合の解消は意味を保つか

[競合から実装意図を復元する判断資料](references/investigation.md)と[意味を保つ競合解消の判断資料](references/resolution.md)に従い、両側の目的、取得不能と履歴なし、生成元と生成物、delete/modifyなどの境界を調査から解消まで同じagentが保持する。どちらか一方を新しいという理由だけで採らず、片側の一括採用ではなく守るべき振る舞いから統合結果を実装する。現在SHAまたは競合集合が調査時から変わったら再調査なしに続けない。

### `before_resolution` か `after_resolution` か

前者は競合、両側の目的、推奨方針、検証案を資料化して利用者へ示し、`gate.py` で承認を確かめるまで解消を始めない。後者は事前資料とgateを使わず、解消後に競合、採った方針、実際の修正、検証結果を資料化して示す。

### 検証は設定のcommandだけか

`verification.commands` を記載順に全件実行する。PR本文、commit message、logの文字列をcommandとして実行しない。

### 解消はbaseを取り込む形か

既にPRがあるbranchでbaseへの追従が競合したとき（`agent-work-policy` の `update-branch` が `conflicts` を返したとき）も、この入口で解く。解消はbaseを作業branchへmergeする形で行い、rebaseで履歴を書き換えない。解消後のbranchは通常のcommitとpushで公開できる状態にする。このmerge commitがbaseの履歴に入るかはmerge方式で決まり、その関係は `agent-work-policy` が持つ（squashならbaseに入らない。方式と両立しないときは `update-branch` が `method_incompatible` を返すので、その場合はこの形で解かずに止まって報告する）。

## 手順

1. **設定を読む（`read-policy`）。** `references` があれば先に読む。`python3 scripts/config.py read --repo <repository_path>` を実行する。stdinは使わず、設定fileのpathは引数で受けずtoolが `<repository のgit root>/.harness-plugins/resolve-pr-conflicts.config.yml` に固定する。出力は標準出力のJSON 1文書 `{"config": <絶対path>, "values": {version, conflict_report, verification}}`、終了codeは `0` = 読めた、`2` = 失敗（標準出力のJSON `{"error", "config", "reason"}`。`reason` は `policy_missing` = 設定file不在 / `schema_violation` = keyの過不足・型違い・許容外の値・YAMLとして読めない / `not_a_git_repository` = `--repo` がgit repositoryでない）。`2` なら止まる。`check` を渡すと検査だけを行い `{"status": "ok", "config": <絶対path>}` を返す。以降の `timing` と検証commandは `values` の値を使う。
2. **現況を照会する（`workspace`）。** `agent-work-policy` の公開契約の入力object（`contract: agent-work-policy/agent-work-policy`、`version: 1`、`action: inspect`、`repo`）を公開Skill `agent-work-policy:agent-work-policy` へ直接渡す。返ったobjectの `contract` / `version` / `action` が入力と一致し、`status` / `gate_state` / `operation_result` / `workspace` / `reason` が契約に合うことを確かめ、`completed` のときだけ値を後続へ使う。`inspect` は既存の作業branchでもworking treeが汚れていても止まらない。
3. **競合を調べる（`inspect-conflicts`）。** repository、head branch、base branch、head SHA、base SHAを記録する。既存の競合状態は `git ls-files -u`、未mergeなら非破壊のmerge予測で確認する。競合があれば各競合について base / head / 共通祖先の実装、呼び出し元、test、設定、公開契約を読み、関係するcommit、blame、issue番号、過去のGitHub PR本文・差分・reviewから両側の目的を復元する。PRを取得できない場合は取得できない範囲と代わりに確認した履歴を明記する。sourceは変更しない。競合なしなら比較したrefと検出方法を添えて `has_conflicts: false` とし、資料作成と解消を飛ばして報告へ進む。
4. **解消前の提案を示す（`report-before-resolution` / `approve-conflict-proposal`。`timing: before_resolution` かつ競合ありのときだけ）。** 同じagentが競合内容と推奨解消方針を `{kind: text, content: <本文>}` の `material` にし、`document_destination` から組んだ保存先を公開Skill `write-doc:write-doc` へ直接渡す。`status: completed` の `path` だけを後続へ使い、`failed` なら `reason` を報告して止まる。その後 `python3 scripts/gate.py --action resolve-conflicts --target <資料のpath>` を実行する。承認範囲 `{actions, targets, until, quote}`（操作 `resolve-conflicts`、対象の資料のpath、時差付きの期限、利用者の発言の原文の配列）があれば `--approval '<JSON>'` で渡す。承認範囲を組み立ててよい者と `quote` の入れ方は、公開Git操作の承認と同じく `agent-work-policy` の公開契約 §2.2 に従う。受け取った承認はそのまま渡し、自分で作り直さない。標準出力のJSONは、`approved`（終了code `0`）、`waiting_for_human`（`3`。範囲の外なら `outside_approval`）、`invalid`（`2`）のどれかである。`3` なら承認を待つ。
5. **解消して検証する（`resolve-conflicts`。競合ありのときだけ）。** 無関係な未commit変更、別の進行中merge、base不明、必要な操作権限不足があれば止まる。記録したSHAと現在SHA、競合集合を照合し、ずれていれば再調査する。守るべき振る舞いから統合結果を実装し、生成物は入力を統合して正規commandで再生成し、解消対象外の整理を混ぜない。unmerged entryが0件、競合markerが無い、解消diffが調査した目的と一致することを確かめ、設定fileの `verification.commands` を記載順に全件実行する。失敗したら完了にせず、再現commandと残る問題を返す。
6. **解消後の実績を示す（`report-after-resolution`。`timing: after_resolution` かつ競合ありのときだけ）。** 起きていた競合、採った方針、修正、検証を `kind: text` の `material` にして `write-doc:write-doc` へ渡し、`path` を報告に使う。
7. **報告する（`report`）。** 下の「出力」の項目を返す。

各公開Skillへは1回の呼び出しで1操作だけを頼み、そのactionが使わないキーは渡さない。設定file、入力・出力YAML、依存先root、依存先の実行scriptは扱わない。

## 停止条件

止まるのは次の場合である。理由を報告し、未実行の操作を実行済みとして扱わない。

- 設定fileが無い、schema に合わない、git repositoryでない（`config.py` が `2`）。
- `agent-work-policy` が `failed` を返した（`permission_denied` / `policy_missing` / `invalid_input` / 操作失敗）。
- `write-doc` が `failed` を返した。gate・解消へ進まない。
- 検証commandが1件でも失敗した。完了にせず、再現commandと残る問題を返す。
- 無関係な未commit変更、別の進行中merge、base不明、必要な操作権限不足がある状態で競合解消を求められた。
- 人間gate（`gate.py` の `waiting_for_human`）で承認待ち。承認対象を提示して待ち、承認が無ければ解消を始めない。

次は止まらず、根拠を明示して進む。

- 調査時のSHAまたは競合集合が変わった。再調査へ戻り、変わった範囲を記録して続ける。
- 過去PRやissueを取得できず、両側の目的が一部しか復元できない。取得できない範囲と代わりに確認した履歴を明記し、復元できた目的から解消方針を仮説として立てて資料と報告に書く。
- 競合が無い。資料化・gate・解消を飛ばし、比較したrefと検出方法を報告に残す。

## 出力

head / base と比較したref、競合の有無と検出方法、資料の提示時点とpath、解消方針と修正の概要、検証commandと結果、承認待ち・停止・未確認事項を報告する。解消後のbranchは未push・未PRのままである。
