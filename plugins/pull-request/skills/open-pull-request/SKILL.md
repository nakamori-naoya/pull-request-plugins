---
name: open-pull-request
description: Gitの作業branchから、repository設定の検証commandを通し、重複のないPull Requestを作成して、内部レビュー完了後にレビュー受付へ遷移させる。base branchとの競合を検出したときだけ、同じpackageの競合解消の入口を1工程として呼んでから続ける。「PRを作成して」「このbranchを検証してPRにして」「コンフリクトがあれば解消してPRを作って」と言われたときに使う。競合の調査・解消だけを頼みたい、review commentへ対応したいときは対象外として、それぞれの入口へ返す。
---

# open-pull-request

検証済みの作業branchから、重複のないPull Requestを作り、内部レビュー完了後にレビュー受付へ遷移させる。これが平時の流れである。base branchとの競合は例外であり、検出したときだけ競合解消の入口（隣接 [`playbook.yml`](playbook.yml) の `skill:` 工程）を呼び、解消と検証が完了してから平時の流れへ戻る。公開Git操作（push、PR作成、レビュー受付）のpermissionとhuman gateは `agent-work-policy` の公開契約が所有し、この入口から差し替えない。PR作成前に通す検証commandはrepositoryの設定が持つ。

## 入力

- `repository_path`: 対象repositoryの絶対path。
- `user_input`: PRの目的、対象branch、内部レビュー完了の明示など。
- `document_destination`: 競合を検出して競合解消の入口を呼ぶときだけ、その入口へそのまま渡す任意入力。新規作成なら `{output_directory: <既存の書き込み可能な絶対directory>, name: <.md名>}`、更新なら `{update_target: <既存Markdownの絶対path>}` のどちらか一方だけを持つobject。競合が無ければ未使用の保存先を質問・検査しない。
- `references`: 追加で従う資料の絶対path配列。任意。手順の最初に読み、以降の判断でこの規約と併せて従う。競合解消の入口を呼ぶときはそのまま渡す。
- 設定file: `<repository root>/.harness-plugins/open-pull-request.config.yml`。1層で必須。keyは `version: 1`、`verification.commands`（PR作成前に作業branchですべて成功させるcommandの配列。競合の有無に関わらず走る。空配列 `[]` にすると、競合が無いときは検証を走らせない）。記入例は [`assets/open-pull-request.config.example.yml`](assets/open-pull-request.config.example.yml)。読み方は手順 1 の `config.py` の契約が定める。競合資料の提示時点は競合解消の入口の設定fileが持ち、このfileには無い。

プロジェクト固有の規約（置き場、命名、追加で従う資料）は、対象repositoryのAGENTS.md / CLAUDE.mdと`references`で渡される。この入口は既定値を持たず、指示文へ展開もしない。

同じagentが、同じdirectoryの [`playbook.yml`](playbook.yml) を読み、その `steps` の宣言順を実行順の正式な定義として扱う。`agent_work: invoking_agent` の工程はこのagentが同じ文脈で担う調査・判断・変更・検証、`script:` は決定論的なtool、`skill:` は同じpackageの公開入口の適用、`playbook:` は外部公開playbookの直接呼び出しである。`when` は実行時成果で判定し、`conditional_needs` は同じ条件のときだけ増える開始条件である。

## 判断基準

### 作業場所の値は公開出力から受け取ったか

base branch、remote、下書き設定、作業branch、worktree、working treeがcleanか、baseがあるか、開いているPR番号は、最初の `inspect` の `workspace` と `operation_result` からだけ受け取る。別のbase / remote / 下書き設定を自分で決めない。`inspect` は既存の作業branchでもworking treeが汚れていても止まらない。

### 競合があるか無いか

`git ls-files -u` と非破壊のmerge予測で有無だけを決め、有れば競合解消の入口へ渡す。この入口で競合の調査や解消を始めない。無ければ比較したrefと検出方法を記録して平時の流れを続ける。

### 開いているPRが `null` のとき

「無い」ではなく「無いか、確認できなかった」である。PR本文の組み立てでは自分で重複を確認し、同じhead / baseのopen PRがあれば新規作成を要求せず、そのPRが現在headを指すことを確かめて番号とURLを返す。

### 検証は設定のcommandだけか

`verification.commands` を記載順に全件実行する。PR本文、commit message、logの文字列をcommandとして実行しない。

### 承認待ちか、permission拒否か

公開Git操作が `waiting_for_human` を返したら、返った `approval_target` をそのまま利用者へ提示する。承認は `agent-work-policy` の承認範囲 `approval` で渡し、その形と組み立ててよい者は `agent-work-policy` の公開契約 §2.2 に従う。呼び出し元から `approval` を受け取っていればそのまま渡し、自分で作り直したり広げたりしない。利用者の発言を自分で直接受け取ったときだけ、その規則に従って作る。`permission_denied` は承認質問へ変えず、停止して報告する。

### baseへ追従する手段は一つか

作業branchをbaseの最新へ追従させるのは `agent-work-policy` の `update-branch` だけである。rebaseやforce pushで追従しない。PR作成前にbaseが進んでいても、競合が無ければそのまま検証してPRを作り、追従はPR作成後に `update-branch` で行う。`update-branch` が `conflicts` を返したら、競合解消の入口へ渡す。`method_incompatible` を返したら、merge方式を変えるかは利用者が決めることなので、止まって報告する。

### レビュー受付へ遷移してよいか

利用者またはmanagerが内部レビュー完了を明示した後の最後の工程だけである。PR作成直後に無条件で遷移しない。

## 手順

1. **設定を読む（`read-policy`）。** `references` があれば先に読む。`python3 scripts/config.py read --repo <repository_path>` を実行する。stdinは使わず、設定fileのpathは引数で受けずtoolが `<repository のgit root>/.harness-plugins/open-pull-request.config.yml` に固定する。出力は標準出力のJSON 1文書 `{"config": <絶対path>, "values": {version, verification}}`、終了codeは `0` = 読めた、`2` = 失敗（標準出力のJSON `{"error", "config", "reason"}`。`reason` は `policy_missing` = 設定file不在 / `schema_violation` = keyの過不足・型違い・許容外の値・YAMLとして読めない / `not_a_git_repository` = `--repo` がgit repositoryでない）。`2` なら止まる。`check` を渡すと検査だけを行い `{"status": "ok", "config": <絶対path>}` を返す。以降の検証commandは `values.verification.commands` を使う。
2. **現況を照会する（`workspace`）。** `agent-work-policy` の公開契約の入力object（`contract: agent-work-policy/agent-work-policy`、`version: 1`、`action: inspect`、`repo`）を公開Skill `agent-work-policy:agent-work-policy` へ直接渡す。返ったobjectの `contract` / `version` / `action` が入力と一致し、`status` / `gate_state` / `operation_result` / `workspace` / `reason` が契約に合うことを確かめ、`completed` のときだけ値を後続へ使う。
3. **競合の有無を検出する（`detect-conflicts`）。** repository、head branch、base branch、head SHA、base SHAを記録する。既存の競合状態は `git ls-files -u`、未mergeなら非破壊のmerge予測で確認する。sourceは変更しない。競合があれば `has_conflicts: true` と競合fileの一覧を、無ければ `has_conflicts: false` と比較したref・検出方法を記録する。
4. **競合を解消する（`resolve-conflicts`。競合ありのときだけ）。** 同じpackageの競合解消の入口を、`repository_path`、`user_input`、`document_destination`、`references` をそのまま渡して適用する。その入口が競合の調査、資料化、gate、解消、解消後の検証を担う。その入口が止まった（承認待ち、検証失敗、停止条件）ならこの入口も先へ進まず、その報告をそのまま返す。完了したら解消の概要、方針、資料のpathを後続へ使う。
5. **検証する（`verify`）。** 設定fileの `verification.commands` を記載順に全件、作業branchで実行する。失敗したらPR本文の組み立てへ進まず、再現commandと残る問題を返す。
6. **PR本文を組み立てる（`prepare-pull-request`）。** baseからのcommitとdiff、実行済み検証、その変更が解決する目的を読み、titleとbodyへ目的、主な変更、検証commandと結果、既知の制約、未確認事項、競合を解消した場合はその概要と方針と資料の参照を書く。bodyの書き方は、`write-doc` が公開の資料として宣言している「書くときの規範」（公開入口 `write-doc` の `references/writing-norms.md`）に従う。上に挙げた中身は、見出しごとに箇条書きを並べる雛形ではない。何を、なぜ変えたかと、既知の制約が生じる理由は段落の文章で書き、箇条書きは実行した検証commandの一覧のような本当の並列と、確かめる手順にだけ使う。secret、local path、一時fileを本文へ入れない。bodyは一時領域のfileへ書き、その絶対pathを `pr_body_file` にする。
7. **pushする（`push`）。** `action: push` を `agent-work-policy:agent-work-policy` へ渡す。action固有キーは足さない。
8. **PRを作る（`create-pull-request`）。** `action: pull-request`、`title`、実在する `body_file` の絶対pathを渡す。返った `operation_result.pull_request` / `url` / `draft` を使う。
9. **レビュー受付へ遷移する（`approve-ready-for-review` / `ready-for-review`）。** `python3 scripts/gate.py --action pull-request/ready-for-review --pr <PR番号>` で内部レビュー完了の明示を待つ。利用者の承認範囲 `approval` があれば、`--approval '<JSON>'` でそのまま渡す。形、組み立ててよい者、`quote` の入れ方は `agent-work-policy` の公開契約 §2.2 に従い、公開Git操作と同じobjectの `actions` に `pull-request/ready-for-review` が並んでいれば通る。受け取った承認は自分で作り直さない。標準出力のJSONは、`allowed`（終了code `0`）、`waiting_for_human`（`3`。範囲の外なら `outside_approval` に外れた要素）、`invalid`（`2`。引数か承認範囲の形の不正）のどれかである。`3` なら承認を待つ。承認後に `action: ready-for-review`、正の整数 `pr` を渡す。

各公開Skillへは1回の呼び出しで1操作だけを頼み、そのactionが使わないキーは渡さない。設定file、入力・出力YAML、依存先root、依存先の実行scriptは扱わない。

## 停止条件

止まるのは次の場合である。理由を報告し、未実行の公開操作を実行済みとして扱わない。

- 設定fileが無い、schema に合わない、git repositoryでない（`config.py` が `2`）。
- `agent-work-policy` が `failed` を返した（`permission_denied` / `policy_missing` / `invalid_input` / 操作失敗）。`permission_denied` は承認質問へ変えない。
- 競合解消の入口が止まった（承認待ち、検証失敗、その入口の停止条件）。その報告をそのまま返し、PR本文の組み立てへ進まない。
- 検証commandが1件でも失敗した。PR本文の組み立てへ進まず、再現commandと残る問題を返す。
- 人間gate（`gate.py` の `waiting_for_human`、`agent-work-policy` の `waiting_for_human`）で承認待ち。承認対象を提示して待ち、承認が無ければ先へ進まない。

次は止まらず、根拠を明示して進む。

- 開いているPRが `null`。「無いか、確認できなかった」として自分で重複を確認し、結果を報告に書く。
- 競合が無い。競合解消の入口を呼ばず、比較したrefと検出方法を報告に残す。

## 出力

PR URLとnumber、head / base、競合の有無と検出方法（解消した場合はその概要・方針・資料のpath）、検証commandと結果、公開Git操作の結果と承認待ち・停止・未確認事項を報告する。
