# Pull Request

Pull Requestの作成、競合の解消、reviewへの対応で、AIエージェントが自分では外しやすい判断だけを配る、Claude Code/Codex両対応のmarketplaceである。公開するのはpackage `pull-request`（`./plugins/pull-request`）1件と、skill 3つである。操作は `git` と `gh` で直接行い、この package は手順も設定も持たない。

## 三つの入口が持つ判断

`open-pull-request` は、同じheadとbaseのPRが既にあれば作らないこと、競合があれば先に解消へ回すこと、本文に何をなぜ変えたかを文章で書くこと、draftを外すのは内部レビューの完了が明示されてからであることを持つ。

`resolve-pr-conflicts` は、競合を解く前に、現行実装と過去のcommitとPRから両側の意図を復元することを持つ。片側の一括採用で解かず、両側の目的を同時に満たせないときや、欠けた情報が方針を変えるときは止まる。

`respond-to-pr-review` は、review commentをsourceとtestに照らしてaccept、reject、deferに分け、採否を利用者に確かめてから、採用分だけを直すことを持つ。

commit、push、merge、baseへの追従の規律は `agent-work-policy` が持つ。

## 利用例

```text
repositoryの規約に従って競合を解消し、検証済みPRを作って。
```

```text
PR #42のreview commentを評価し、採用する指摘だけを修正して検証して。
```

## インストール

インストールするのは`pull-request@pull-request`です。commit、push、mergeの規律は`agent-work-policy@agent-work-policy`が持つので、一緒に入れます。下のコマンドには、それも含めています。

### Codex

利用するCodexと同じ設定環境で実行してください。

```bash
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

## 検証

```bash
bash scripts/validate.sh
```

`scripts/validate.sh` は、配置とmanifestの一致と、SKILLのnameを検査する。保守toolの実装元は兄弟checkoutの `../harness-tools/` で、このrepositoryは複製を持たない。
