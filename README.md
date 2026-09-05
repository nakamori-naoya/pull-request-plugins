# Pull Request

Pull Requestの競合調査・解消・作成と、reviewの評価・修正・検証・公開を扱うClaude Code/Codex両対応marketplaceである。

## こんなときに使う

**PRを作る、競合を意味に基づいて解く、レビュー指摘へ安全に対応する作業をAIエージェントへ任せたいときに使う。** 公開操作は`agent-work-policy`へ委譲するため、repositoryごとの許可とhuman gateを保ったまま進められる。

- branchの差分、検証結果、既存PRを確認して重複のないPRを作りたい
- base branchとの競合について、両側の変更意図を先に調べたい
- 行単位の機械的な選択ではなく、履歴と過去PRに基づいて競合を解消したい
- review commentをそのまま採用せず、sourceと照合して採否を判断したい
- 採用した指摘だけを修正し、検証、commit、pushまで進めたい

## どの機能を使うか

| やりたいこと | 選ぶ機能 |
|---|---|
| 競合の有無と両側の意図だけを調べる | `pr-conflict-inspect` |
| 調査結果に基づいて競合を解消する | `pr-conflict-resolve` |
| 検証済みbranchからPRを作る | `pr-create` |
| 競合調査・必要な解消・PR作成を一続きで行う | `pull-request` |
| review commentの採否だけを評価する | `pr-review-assess` |
| 採用済み指摘だけをsourceへ反映する | `pr-review-apply` |
| review修正を指定commandで検証する | `pr-review-verify` |
| 評価から修正、検証、公開まで一続きで行う | `pr-review-response` |

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

### Codex

Codexのpluginコマンドには`--scope`がない。通常の手順はuser単位でmarketplaceとpluginを登録する。

```bash
codex plugin marketplace add nakamori-naoya/pull-request-plugins
codex plugin add pull-request@pull-request
```

このrepositoryだけに分離したい場合は、repository専用の`CODEX_HOME`を作り、インストール時と利用時に同じ値を指定する。

```bash
mkdir -p .codex-home
export CODEX_HOME="$PWD/.codex-home"

codex plugin marketplace add nakamori-naoya/pull-request-plugins
codex plugin add pull-request@pull-request
codex
```

`CODEX_HOME`には認証、設定、ログ、session、plugin metadataも保存されるため、このdirectoryはGit管理しない。

### Claude Code

Claude Codeは次のscopeを選べる。

| scope | 対象 |
|---|---|
| `user` | user全体。省略時の既定値 |
| `project` | このrepositoryで有効にする設定をGitでチーム共有する |
| `local` | このrepositoryで有効にするが、Git共有せず自分だけで使う |

repository設定としてインストールする場合は`project`を指定する。`CLAUDE_PLUGIN_SCOPE`を`user`または`local`へ変えれば、同じ手順でscopeを切り替えられる。

```bash
CLAUDE_PLUGIN_SCOPE=project

claude plugin marketplace add nakamori-naoya/pull-request-plugins --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install pull-request@pull-request --scope "$CLAUDE_PLUGIN_SCOPE"
```

利用者がインストールするのはこのpackageだけである。競合調査、競合解消、PR作成、review評価・適用・検証と2つのplaybookは同梱し、内部機能を個別のインストール対象にはしない。

## インストール済みである必要があるplugin

このrepository外の依存だけを記載する。

- `write-doc@write-doc`
- `agent-work-policy@agent-work-policy`

別repositoryへの依存は公開playbook packageの`plugin@marketplace`だけを宣言し、内部機能名へ依存しない。versionは固定せず、開発用map、同じrepository、runtimeのinstall cacheの順に候補を調べ、解決したmanifestのidentityと必要なskillを検査する。

## 設定の上書きと優先順位

設定を持つpluginは、優先順位が最も高い1ファイルだけを選ぶ。複数層をマージしないため、上書きするYAMLには同梱設定と同じ必須項目をすべて含める。必須項目の不足、未知のキー、許可されていない値があれば実行を停止する。

skillの静的設定は、上から順に優先する。

1. scope: `<scope>/<plugin-name>.config.yml`。呼び出し元がscopeを渡した実行だけで使う
2. local: `<repo>/.harness-plugins/<plugin-name>.local.yml`。端末固有で、通常はcommitしない
3. repository: `<repo>/.harness-plugins/<plugin-name>.config.yml`
4. personal: `$XDG_CONFIG_HOME/harness-plugins/<plugin-name>.config.yml`（未設定時は `~/.config/harness-plugins/<plugin-name>.config.yml`）
5. bundled defaults: plugin同梱の既定設定

playbookの静的設定は、scope、repository、personal、同梱 `playbook.yml` の順で優先する。playbookにはlocal層がない。入口playbook自身は通常のrepository設定を使い、下段のpluginへscopeを渡す。単体呼び出しではscopeを読まない。

skillでは、同梱設定の `prompt_parameters` に宣言されたpathだけ、依頼で明示された値を `--override=<path>=<value>` として最終上書きできる。宣言されていないpathを任意に上書きすることはできない。

たとえば入口は `<repo>/.harness-plugins/pull-request.config.yml`、その入口から呼ぶ `write-doc` だけの設定は `<repo>/.harness-plugins/scopes/pull-request/write-doc.config.yml` に置く。

## 検証

```bash
bash scripts/validate.sh
```

## 実行契約の検証と配布

`python3 scripts/doctor.py --repository . --repo <対象repository>` はCLI構文、公開skillと設定・依存の解決を読み取り専用で診断する。設定解決を含めない検査は `--distribution-only` を明示する。

`bash scripts/validate.sh` は機能・不正入力・配布の検証を行い、GitHub Actionsの `validate (ubuntu-latest)` / `validate (macos-latest)` でも実行する。[意味的評価シナリオ](evals/scenarios.json)は `scripts/evaluate-skills.py` で実モデルと別のjudgeモデルへ渡し、モデルID・設定・入力・応答・判定根拠を記録する。モデル評価は構造検証と別に実施し、未実行を成功として扱わない。

version更新は `python3 scripts/release.py --plugin <公開plugin名> --version <semver> --notes <変更内容> --breaking <互換性への影響> --migration <移行方法> --checks <codex/claudeの検証結果JSON>` で計画を確認し、`--apply` で両runtimeのmanifestとmarketplaceを更新する。検証結果には未検証も明示できる。配布・外部publishは別操作であり、このcommandでは行わない。

### 破壊的変更と移行

公開入口は同名SKILLの薄い別入口を廃止して一意にした。古い内部SKILL pathを直接参照している呼出元は公開manifestのskillsへ切り替える。設定の一時fileはshell終了では削除されず、返却された絶対pathを次の工程へ渡し、完了・停止時にrun-configのcleanupでそのrunだけを削除する。以前の一時fileや異なる実行identityを再利用せず、新しいrunを開始する。

検証CLIのstdoutはJSONのみとなり、commandの出力はresults[].log_pathへ移る。呼出元はstdoutをログとして連結せずJSONとして読み、失敗時のexit_codeとlog_pathを参照する。
