# Pull Request

Pull Requestの競合調査・解消・作成と、reviewの評価・修正・検証・公開を扱うClaude Code/Codex両対応marketplaceである。

## インストール

### Codex

Codexのpluginコマンドには`--scope`がない。通常の手順はuser単位でmarketplaceとpluginを登録する。

```bash
codex plugin marketplace add nakamori-naoya/pull-request-plugins
codex plugin add pr-conflict-inspect@pull-request
codex plugin add pr-conflict-resolve@pull-request
codex plugin add pr-create@pull-request
codex plugin add pull-request@pull-request
codex plugin add pr-review-assess@pull-request
codex plugin add pr-review-apply@pull-request
codex plugin add pr-review-verify@pull-request
codex plugin add pr-review-response@pull-request
```

このrepositoryだけに分離したい場合は、repository専用の`CODEX_HOME`を作り、インストール時と利用時に同じ値を指定する。

```bash
mkdir -p .codex-home
export CODEX_HOME="$PWD/.codex-home"

codex plugin marketplace add nakamori-naoya/pull-request-plugins
codex plugin add pr-conflict-inspect@pull-request
codex plugin add pr-conflict-resolve@pull-request
codex plugin add pr-create@pull-request
codex plugin add pull-request@pull-request
codex plugin add pr-review-assess@pull-request
codex plugin add pr-review-apply@pull-request
codex plugin add pr-review-verify@pull-request
codex plugin add pr-review-response@pull-request
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
claude plugin install pr-conflict-inspect@pull-request --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install pr-conflict-resolve@pull-request --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install pr-create@pull-request --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install pull-request@pull-request --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install pr-review-assess@pull-request --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install pr-review-apply@pull-request --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install pr-review-verify@pull-request --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install pr-review-response@pull-request --scope "$CLAUDE_PLUGIN_SCOPE"
```

## インストール済みである必要があるplugin

このrepository外の依存だけを記載する。

- `write-doc@write-doc`

playbookの依存は`plugin@marketplace`のidentityだけを宣言し、versionは固定しない。開発用map、同じrepository、runtimeのinstall cacheの順に候補を調べ、解決したmanifestのidentityと必要なskillを検査する。

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
