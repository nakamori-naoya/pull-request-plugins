---
name: open-pull-request
description: Gitの作業branchとbase branchの競合を検出し、現行実装、関連する過去の修正・commit・GitHub PRから意図を理解して解消・検証した後、Pull Requestを作成する。「コンフリクトを解消してPRを作って」「PRを作成して」と言われたときに使う。競合資料はrepository設定により解消前の提案または解消後の実績として提示する。
---

# open-pull-request

競合が無い、または意味を保って解消し検証した作業branchから、重複のないPull Requestを作り、内部レビュー完了後にレビュー受付へ遷移させる。公開Git操作（push、PR作成、レビュー受付）のpermissionとhuman gateは `agent-work-policy` の公開契約が所有し、この入口から差し替えない。競合資料の提示時点と検証commandはrepositoryの設定が持つ。

## 入力

- `repository_path`: 対象repositoryの絶対path。
- `user_input`: PRの目的、対象branch、内部レビュー完了の明示など。
- `document_destination`: 競合資料を作る条件が成立したときだけ使う任意入力。その時点では、新規作成なら `{output_directory: <既存の書き込み可能な絶対directory>, name: <.md名>}`、更新なら `{update_target: <既存Markdownの絶対path>}` のどちらか一方だけを持つobjectを必須とする。競合が無く資料化工程が無効なら、未使用の保存先を質問・検査しない。
- 設定file: `<repository root>/.harness-plugins/open-pull-request.config.yml`。1層で必須。keyは `version: 1`、`conflict_report.timing`（`before_resolution` = 解消前に提案資料を示して承認を待つ / `after_resolution` = 解消後に実績資料を示す）、`verification.commands`（競合解消後、PR作成前にすべて成功させるcommandの配列）。記入例は [`assets/open-pull-request.config.example.yml`](assets/open-pull-request.config.example.yml)。最初の工程で `scripts/config.py` が読み、fileが無い、keyが足りない・余る、`timing` が2値以外なら止まる。

同じagentが、同じdirectoryの [`playbook.yml`](playbook.yml) を読み、その `steps` の宣言順を実行順の正本にする。`agent_work: invoking_agent` の工程はこのagentが同じ文脈で担う調査・判断・変更・検証、`script:` は決定論的な安全gate、`playbook:` は外部公開playbookの直接呼び出しである。`when` は設定fileの値と実行時成果で判定し、`conditional_needs` は同じ条件のときだけ増える開始条件である。

## 判断基準

- **作業場所の値は公開出力から受け取ったか。** base branch、remote、下書き設定、作業branch、worktree、working treeがcleanか、baseがあるか、開いているPR番号は、最初の `inspect` の `workspace` と `operation_result` からだけ受け取る。別のbase / remote / 下書き設定を自分で決めない。`inspect` は既存の作業branchでもworking treeが汚れていても止まらない。
- **開いているPRが `null` のとき。** 「無い」ではなく「無いか、確認できなかった」である。PR本文の組み立てでは自分で重複を確認し、同じhead / baseのopen PRがあれば新規作成を要求せず、そのPRが現在headを指すことを確かめて番号とURLを返す。
- **競合の解消は意味を保つか。** [競合から実装意図を復元する判断資料](references/investigation.md)と[意味を保つ競合解消の判断資料](references/resolution.md)に従い、両側の目的、取得不能と履歴なし、生成元と生成物、delete/modifyなどの境界を調査から解消まで同じagentが保持する。どちらか一方を新しいという理由だけで採らず、片側の一括採用ではなく守るべき振る舞いから統合結果を実装する。現在SHAまたは競合集合が調査時から変わったら再調査なしに続けない。
- **`before_resolution` か `after_resolution` か。** 前者は競合、両側の目的、推奨方針、検証案を資料化して利用者へ示し、`gate.sh` の明示承認を得るまで解消を始めない。後者は事前資料とgateを使わず、解消後に競合、採った方針、実際の修正、検証結果を資料化して示す。
- **承認待ちか、permission拒否か。** 公開Git操作が `waiting_for_human` を返したら、返った `approval_target` をそのまま利用者へ提示し、実際に承認を得たときだけ同じactionを `approved: true` で呼び直す。`permission_denied` は承認質問へ変えず、停止して報告する。
- **レビュー受付へ遷移してよいか。** 利用者またはmanagerが内部レビュー完了を明示した後の最後の工程だけである。PR作成直後に無条件で遷移しない。

## 手順

1. **設定を読む（`read-policy`）。** `python3 scripts/config.py --repo <repository_path>` を実行する。入力はrepositoryの絶対path（設定fileはそのgit rootから固定名で解決する）、出力は `conflict_report.timing` と `verification.commands` を持つ標準出力のJSON、終了codeは `0` = 読めた、`2` = 設定file不在（`policy_missing`）・schema違反・git repositoryでない（診断は標準出力のJSON `error`）。`2` なら止まる。以降の `timing` と検証commandはこの出力の値を使う。
2. **現況を照会する（`workspace`）。** `agent-work-policy` の公開契約の入力object（`contract: agent-work-policy/agent-work-policy`、`version: 1`、`action: inspect`、`repo`）を公開Skill `agent-work-policy:agent-work-policy` へ直接渡す。返ったobjectの `contract` / `version` / `action` が入力と一致し、`status` / `gate_state` / `operation_result` / `workspace` / `reason` が契約に合うことを確かめ、`completed` のときだけ値を後続へ使う。
3. **競合を調べる（`inspect-conflicts`）。** repository、head branch、base branch、head SHA、base SHAを記録する。既存の競合状態は `git ls-files -u`、未mergeなら非破壊のmerge予測で確認する。競合があれば各競合について base / head / 共通祖先の実装、呼び出し元、test、設定、公開契約を読み、関係するcommit、blame、issue番号、過去のGitHub PR本文・差分・reviewから両側の目的を復元する。PRを取得できない場合は取得できない範囲と代わりに確認した履歴を明記する。sourceは変更しない。競合なしなら比較したrefと検出方法を添えて `has_conflicts: false` とし、資料作成と解消を飛ばす。
4. **解消前の提案を示す（`report-before-resolution` / `approve-conflict-proposal`。`timing: before_resolution` かつ競合ありのときだけ）。** 同じagentが競合内容と推奨解消方針を `{kind: text, content: <本文>}` の `material` にし、`document_destination` から組んだ保存先を公開Skill `write-doc:write-doc` へ直接渡す。`status: completed` の `path` だけを後続へ使い、`failed` なら `reason` を報告して止まる。その後 `bash scripts/gate.sh --report-ref <path>` を実行する。標準出力のJSONが `waiting_for_human` で終了code `3` なら承認を待ち、利用者の明示承認後だけ `--approved` を付けて呼び直す（`approved` / `0`）。`2` は引数不備。
5. **解消して検証する（`resolve-conflicts`。競合ありのときだけ）。** 無関係な未commit変更、別の進行中merge、base不明、必要な操作権限不足があれば止まる。記録したSHAと現在SHA、競合集合を照合し、ずれていれば再調査する。守るべき振る舞いから統合結果を実装し、生成物は入力を統合して正規commandで再生成し、解消対象外の整理を混ぜない。unmerged entryが0件、競合markerが無い、解消diffが調査した目的と一致することを確かめ、設定fileの `verification.commands` を記載順に全件実行する。失敗したら完了にせず、再現commandと残る問題を返す。
6. **解消後の実績を示す（`report-after-resolution`。`timing: after_resolution` かつ競合ありのときだけ）。** 起きていた競合、採った方針、修正、検証を `kind: text` の `material` にして `write-doc:write-doc` へ渡し、`path` を後続へ使う。
7. **PR本文を組み立てる（`prepare-pull-request`）。** 競合なし、または解消と全検証が成功した場合だけ進む。baseからのcommitとdiff、実行済み検証、その変更が解決する目的を読み、titleとbodyへ目的、主な変更、検証commandと結果、既知の制約、未確認事項、競合を解消した場合はその概要と方針と資料の参照を書く。secret、local path、一時fileを本文へ入れない。bodyは一時領域のfileへ書き、その絶対pathを `pr_body_file` にする。
8. **pushする（`push`）。** `action: push` を `agent-work-policy:agent-work-policy` へ渡す。action固有キーは足さない。
9. **PRを作る（`create-pull-request`）。** `action: pull-request`、`title`、実在する `body_file` の絶対pathを渡す。返った `operation_result.pull_request` / `url` / `draft` を使う。
10. **レビュー受付へ遷移する（`approve-ready-for-review` / `ready-for-review`）。** `bash scripts/gate.sh --report-ref <PR番号またはURL>` で内部レビュー完了の明示を待ち、承認後に `action: ready-for-review`、正の整数 `pr` を渡す。

各公開Skillへは1回の呼び出しで1操作だけを頼み、そのactionが使わないキーは渡さない。設定file、入力・出力YAML、依存先root、依存先の実行scriptは扱わない。

## 停止条件

- 設定fileが無い、または schema に合わない。`config.py` の診断を報告して止まる。
- `agent-work-policy` が `failed` を返した（`permission_denied` / `policy_missing` / `invalid_input` / 操作失敗）。`reason` を報告して止まる。
- `write-doc` が `failed` を返した。`reason` を報告し、gate・解消・公開操作へ進まない。
- 調査時のSHAまたは競合集合が変わった。再調査へ戻る。
- 検証commandが1件でも失敗した。PR本文の組み立てへ進まない。

## 出力

PR URLとnumber、head / base、競合の有無、資料の提示時点とpath、解消方針、検証結果、公開Git操作の結果と承認待ち・停止・未確認事項を報告する。
