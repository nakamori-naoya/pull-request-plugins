# Pull Request

Pull Requestの作成、競合の調査・解消、reviewの評価・修正・検証・公開を扱うClaude Code/Codex両対応marketplaceである。公開するインストール対象はpackage `pull-request`（`./plugins/pull-request`）1件で、公開入口は自己完結skill `open-pull-request`（平時）、`resolve-pr-conflicts`（例外）、`respond-to-pr-review` の3つである。

## こんなときに使う

**PRを作る、競合を意味に基づいて解く、レビュー指摘へ安全に対応する作業をAIエージェントへ任せたいときに使う。** 公開操作は`agent-work-policy`へ委譲するため、repositoryごとの許可とhuman gateを保ったまま進められる。

- branchの差分、検証結果、既存PRを確認して重複のないPRを作りたい
- base branchとの競合について、両側の変更意図を先に調べたい
- 行単位の機械的な選択ではなく、履歴と過去PRに基づいて競合を解消したい
- review commentをそのまま採用せず、sourceと照合して採否を判断したい
- 採用した指摘だけを修正し、検証、commit、pushまで進めたい

## 公開入口を選ぶ

次の入口から依頼します。各入口は `SKILL.md`、隣接 `playbook.yml`、`references/`、`scripts/`、`assets/` だけで完結し、内部skillを持ちません。

| やりたいこと | 公開入口 | repository設定 |
|---|---|---|
| 検証済みbranchからPRを作る（競合を検出したときだけ `resolve-pr-conflicts` を呼ぶ） | `open-pull-request` | `<repo>/.harness-plugins/open-pull-request.config.yml` |
| 指定branchまたはPRの競合を調査・資料化し、gateを経て解消・検証する | `resolve-pr-conflicts` | `<repo>/.harness-plugins/resolve-pr-conflicts.config.yml` |
| 評価から修正、検証、公開まで一続きで行う | `respond-to-pr-review` | `<repo>/.harness-plugins/respond-to-pr-review.config.yml` |

設定fileは1入口1つ、1層で必須であり、同梱既定へのfallbackは無い。各入口の `assets/<入口>.config.example.yml` を写して全keyを書く。読み取りは各入口の `scripts/config.py check|read --repo <repository_path>` が行い、stdoutのJSON 1文書と終了code（`0` / 失敗は `2` と `reason`）を返す。公開Git操作（push、PR作成、commit）のpolicyは `agent-work-policy` の設定（`<repo>/.harness-plugins/agent-work-policy.config.yml`）が持ち、これらの設定fileへは書けない。各入口は任意入力 `references`（追加で従う資料の絶対path配列）を受け、プロジェクト固有の規約は対象repositoryのAGENTS.md / CLAUDE.mdと `references` で渡す。

## 利用例

```text
このbranchの競合を非破壊で調査し、両側の変更意図を説明して。
```

```text
repositoryの規約に従って競合を解消し、検証済みPRを作って。
```

```text
PR #42のreview commentを評価し、採用する指摘だけを修正して検証して。
```

## インストール

インストールするのは`pull-request@pull-request`です。外部の工程を実行するため、`write-doc@write-doc`、`agent-work-policy@agent-work-policy`も必要です。下のコマンドには、それらも含めています。

内部のスキルは同梱されています。個別にインストールせず、公開入口から利用してください。

### Codex

利用するCodexと同じ設定環境で実行してください。

```bash
codex plugin marketplace add nakamori-naoya/write-doc-plugins
codex plugin add write-doc@write-doc
codex plugin marketplace add nakamori-naoya/agent-work-policy-plugins
codex plugin add agent-work-policy@agent-work-policy
codex plugin marketplace add nakamori-naoya/pull-request-plugins
codex plugin add pull-request@pull-request
codex plugin list
```

一覧で導入先を確認し、新しい会話で利用してください。

### Claude Code

次は自分の全プロジェクトで使う例です。このプロジェクトのチームで共有する場合は`project`、このプロジェクトで自分だけが使う場合は`local`に変更し、利用先のディレクトリで実行してください。

```bash
CLAUDE_PLUGIN_SCOPE=user
claude plugin marketplace add nakamori-naoya/write-doc-plugins --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install write-doc@write-doc --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin marketplace add nakamori-naoya/agent-work-policy-plugins --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install agent-work-policy@agent-work-policy --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin marketplace add nakamori-naoya/pull-request-plugins --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install pull-request@pull-request --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin list
```

一覧で導入を確認し、Claude Codeを再起動してください。すでに導入しているパッケージは、次の更新手順を使ってください。

## 更新する

GitHubから登録したmarketplaceを更新し、その公開パッケージを更新します。新規インストールと同じCodexの設定環境、Claude Codeの適用範囲を使ってください。

### Codex

```bash
codex plugin marketplace upgrade pull-request
codex plugin add pull-request@pull-request
codex plugin list
```

更新後は新しい会話で確認してください。ローカルのパスからmarketplaceを登録した場合は、Git版の更新コマンドではなく、その登録先のソースを更新してから追加し直します。

### Claude Code

```bash
# インストール時に合わせてuser / project / localを選ぶ
CLAUDE_PLUGIN_SCOPE=user
claude plugin marketplace update pull-request
claude plugin update pull-request@pull-request --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin list
```

更新後はClaude Codeを再起動してください。外部の依存パッケージも使っている場合は、それぞれのREADMEの更新手順を実行してください。

marketplaceの取得と、インストール済みパッケージの更新は分けて確認します。同じバージョンとして公開された変更は、更新コマンドだけでは反映されない場合があります。「最新」と表示された場合は公開バージョンを確認し、キャッシュ内のファイルを直接編集しないでください。

コマンドは2026-09-06時点のCLIヘルプと、[Codexのmarketplace管理](https://developers.openai.com/plugins/build/plugins)、[Claude Codeの更新仕様](https://code.claude.com/docs/en/plugins-reference#plugin-update)を確認しています。

## インストール済みである必要があるplugin

このrepository外の依存だけを記載する。

- `write-doc@write-doc`
- `agent-work-policy@agent-work-policy`

別repositoryへの依存は各入口の `playbook.yml` の `requires` に `{plugin, marketplace}` で宣言し、`playbook:` の工程として呼ぶ。versionは固定しない。外部playbookには公開契約の入力objectを直接渡し、同じ呼び出しが返す結果objectを直接読む。`agent-work-policy` は契約ID・版・対象repository・1つのactionとそのaction固有値だけを受け取る。`write-doc` v2は型付き `material` と、新規作成の `output_directory` + `name` または更新の `update_target` を排他的に受け取る。入力YAML、中間YAML、依存先root、内部script、結果受取用fileは扱わない。

## 検証

```bash
bash scripts/validate.sh
```

## 保守tool

保守tool（root validator `validate-plugin-repository.py`、`doctor.py`、`lint-consumer-contract.py`、`test-hardening.py`、`release.py`、eval runner）の基準資料は兄弟checkout `../harness-tools/` だけである。このrepositoryは複製も同期機構も持たず、`scripts/validate.sh` は `../harness-tools/tools/` が無ければ止まる。消費側契約lintは依存providerの実配布物（`../grill-plugins` / `../write-doc-plugins` / `../agent-work-policy-plugins`）も要る。CIは `.github/workflows/validate.yml` で `harness-tools` と依存providerを兄弟checkoutし、`harness-tools/ci/validate.sh` で local と同じcommandを実行する。実行時（skillの利用時）に別repositoryや生成CLIは不要である。

## 配置と設定の変更（2026-09-16）

- marketplaceの `source` を `./plugins` から `./plugins/pull-request` へ、公開入口を `plugins/pull-request/skills/{open-pull-request, respond-to-pr-review}` へ移した。隣接 `playbook.yml` の `name` は入口名と同じになった。配置変更はinstall identityを変えるため、release時にmajor bumpが要る。
- 内部skill `pr-conflict-inspect` / `pr-conflict-resolve` / `pr-create` は `open-pull-request` へ、`pr-review-assess` / `pr-review-apply` / `pr-review-verify` は `respond-to-pr-review` へ統合した。判断規律の参照文書と決定論的tool（`assessment.py` / `brief.py` / `verify.sh` / `review-gate.py` / `gate.sh`）は入口へ移した。
- 同日のハーネス進化第3回で、競合の調査・資料化・gate・解消・検証を `resolve-pr-conflicts` 公開入口へ分け、`open-pull-request` は平時の流れ（設定読取 → 照会 → 競合検出 → 検証 → PR準備 → push → PR作成 → レビュー受付gate）に絞った。競合を検出したときだけ `open-pull-request` が `resolve-pr-conflicts` を `steps[].skill` で呼ぶ。`conflict_report.timing` は `resolve-pr-conflicts.config.yml` へ移し、`open-pull-request.config.yml` は `verification.commands`（PR作成前の検証）だけを持つ。設定の読み取りは3入口とも `scripts/config.py check|read --repo` に揃え、`review-gate.py` は同じ固定pathを `--repo` から解決する。
- repositoryごとの方針（`conflict_report.timing` / `verification.commands`、`report` / `permissions` / `gates` / `verification` / `git`）は `playbook.yml` から `<repo>/.harness-plugins/<入口>.config.yml` へ移し、1層・必須にした。`review-gate.py` が schema を検査し、公開Git操作のpermissionやgateの混入を拒否する。
- 設定解決runtime（`prepare.sh` / `resolve.sh` / `run-config.py` / `state.py` / `validate-config.sh`）、4層の設定探索、入口ごとのnested manifest、`dependencies.yml` による束縛の実行時解決を撤去した。
- `agent-work-policy` の呼び名は `agent-work-policy:work-with-policy` から `agent-work-policy:agent-work-policy` になった。
