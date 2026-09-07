# Pull Request

Pull Requestの競合調査・解消・作成と、reviewの評価・修正・検証・公開を扱うClaude Code/Codex両対応marketplaceである。

## こんなときに使う

**PRを作る、競合を意味に基づいて解く、レビュー指摘へ安全に対応する作業をAIエージェントへ任せたいときに使う。** 公開操作は`agent-work-policy`へ委譲するため、repositoryごとの許可とhuman gateを保ったまま進められる。

- branchの差分、検証結果、既存PRを確認して重複のないPRを作りたい
- base branchとの競合について、両側の変更意図を先に調べたい
- 行単位の機械的な選択ではなく、履歴と過去PRに基づいて競合を解消したい
- review commentをそのまま採用せず、sourceと照合して採否を判断したい
- 採用した指摘だけを修正し、検証、commit、pushまで進めたい

## 公開入口を選ぶ

次の入口から依頼します。内部のスキルや処理は、入口が必要に応じて呼び出します。

| やりたいこと | 公開入口 |
|---|---|
| 競合調査・必要な解消・PR作成を一続きで行う | `open-pull-request` |
| 評価から修正、検証、公開まで一続きで行う | `respond-to-pr-review` |

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

別repositoryへの依存は公開playbook packageの`plugin@marketplace`だけを宣言し、内部機能名へ依存しない。versionは固定せず、開発用map、同じrepository、runtimeのinstall cacheの順に候補を調べ、解決したmanifestのidentityと公開playbookの存在を検査する。

外部pluginから使ってよいのは、その公開playbookの4点だけである。参照の形は`${.deps.<論理依存名>.root}`と`${.deps.<論理依存名>.entry}`の**2つ**しかない。

| # | 参照形 | 用途 |
|---|---|---|
| E1 | `${.deps.<x>.root}/scripts/prepare.sh <repo> --input=<絶対path> [--scope=<dir>] [--bindings=<lock>]` | 入力を渡して実行設定を解決する |
| E2 | `${.deps.<x>.root}/playbook.yml` | 段取りの宣言を読む |
| E3 | `${.deps.<x>.root}/scripts/resolve.sh` | `prepare.sh` が内部で呼ぶ入口 |
| E4 | `${.deps.<x>.entry}` | 公開playbook入口の`SKILL.md`の絶対path。実行手順はここに従う |

呼び出しは2段である。消費側がE1で実行設定を解決し、得た絶対pathをE4の`SKILL.md`へ渡して実行させ、入力に書いた書き込み先から公開出力を受け取る。**依存先は`prepare.sh`を実行し直さない。**

外部pluginを`skill:`や`script:`のstepで指すこと、`${.deps.<x>.root}`からE1〜E3以外のpathを組み立てること、`${.deps.<x>.skills.<名前>}`のようなskill名で入口を指すこと、ブラケット形で綴ること、外部の設定ファイル・設定キー・内部の名前を語ることは禁止する。`bash scripts/lint-consumer-contract.py`がこの規則を静的に検査する。

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

doctorのfull診断は、依存を**実配布物**に対して解く。依存先は`HARNESS_PLUGIN_REAL_ROOTS`（契約ID→package rootのJSON）か、兄弟checkout `../<marketplace>-plugins/plugins`（親directoryは`HARNESS_PLUGIN_SIBLING_ROOT`で差し替える）から探し、どちらでも見つからなければfixtureへ倒さず理由付きでNGにする。同梱既定に実値を置かない`prompt_parameters`（`required: true`で`default`が無いもの）を持つskillは、上書きが無ければ必ず落ちるので実行せず、`skipped: requires-override`と必要なパラメータ名を出す。これは配布物の不具合ではないのでNGにしない。

依存参照の検査はresolverとlintが同じ関数で行う。外部依存を指せるのは`${.deps.<論理名>.root}`直下3点と`${.deps.<論理名>.entry}`だけで、それ以外は`external-dependency-path`で落ちる。内部依存（同一package）の`${.deps.<内部名>.skills.<名前>}`は、解決結果に実在するskill名だけを許し、綴り違いや名前の無い形は`internal-skill-unknown`で落ちる。`--explain`の依存行は`[外部] <論理名> → <marketplace>/<plugin> <version> [runtime/source_kind]: <root>`の形で、束縛で実体が変わったときだけ行末に`← <層>`が付く。

CIは同ownerの依存repositoryを兄弟directoryへcheckoutしてからvalidate.shを走らせる。**兄弟のrefは既定でmainである。** PR headと同名のbranchを採るのは、(1)実行が`pull_request`であり、(2)PR headが同一repository（forkではない）で、(3)同ownerの兄弟repoにその名前のbranchが実在する、の3つが揃うときだけで、選んだrefと理由はログへ出る。forkのPR作者はownerの兄弟repoにbranchを作れないため、PRから兄弟checkoutの内容を差し替える経路は無い。code scanningの`actions/untrusted-checkout/medium`はこの根拠により`won't fix`として扱う。

`bash scripts/validate.sh` は機能・不正入力・配布の検証を行い、GitHub Actionsの `validate (ubuntu-latest)` / `validate (macos-latest)` でも実行する。[意味的評価シナリオ](evals/scenarios.json)は `scripts/evaluate-skills.py` で実モデルと別のjudgeモデルへ渡し、モデルID・設定・入力・応答・判定根拠を記録する。モデル評価は構造検証と別に実施し、未実行を成功として扱わない。

version更新は `python3 scripts/release.py --plugin <公開plugin名> --version <semver> --notes <変更内容> --breaking <互換性への影響> --migration <移行方法> --checks <codex/claudeの検証結果JSON>` で計画を確認し、`--apply` で両runtimeのmanifestとmarketplaceを更新する。検証結果には未検証も明示できる。配布・外部publishは別操作であり、このcommandでは行わない。

### 依存先を束縛する`dependencies.yml`

契約ID（`marketplace/plugin`）に対する実体を`{plugin, marketplace}`で束縛する。**top-levelは`version: 1`と`bindings`の2つだけである。** それ以外のキーがあると`[error:binding-file-invalid] reason=top-level-keys`で停止する。

```yaml
version: 1
bindings:
  "write-doc/write-doc": {plugin: write-documents, marketplace: my-marketplace}
  "agent-work-policy/agent-work-policy": {plugin: my-work-policy, marketplace: my-marketplace}
```

置き場所は3層で、下ほど優先する。**層はマージせず、見つかった最優先の1ファイルだけを使う。**

1. personal: `$XDG_CONFIG_HOME/harness-plugins/dependencies.yml`（未設定時は`~/.config/harness-plugins/dependencies.yml`）
2. repository: `<repo>/.harness-plugins/dependencies.yml`
3. scope: `<repo>/.harness-plugins/scopes/<入口playbook>/dependencies.yml`

値に書けるのは`plugin`と`marketplace`だけで、**pathやversionは書けない。** 差し替え先はmarketplace経由（installed cache、同一repository、開発時の`HARNESS_PLUGIN_DEV_ROOTS`）で解決でき、manifestの`metadata.harness.implements`にその契約IDを宣言しているpluginでなければならない。宣言が無ければ`[error:binding-not-implemented]`で停止する。playbook側の`requires`は書き換えない。

入口が選んだ束縛はrun専用のlockへ固定して子へ渡す。同じ実行の中で実体が食い違うことはなく、実行中に`dependencies.yml`を書き換えても、そのrunの解決は変わらない。

### explainの読み方

`scripts/prepare.sh`は`--explain`を引数に取らない。**explainは常にstderrへ出る。** stdoutは解決済みYAMLの絶対path1行だけなので、解決の内訳（選んだ設定層、依存の実体、束縛の出どころ、静的に解けた工程入力）はstderrで読む。`--explain`のような未知optionを渡すとusageを表示してexit 2で止まる。

### 破壊的変更と移行

公開入口は同名SKILLの薄い別入口を廃止して一意にした。古い内部SKILL pathを直接参照している呼出元は公開manifestのskillsへ切り替える。

外部pluginの公開面をplaybook 1枚に限る規則へ移行した。第2入口`mark-ready-for-review`は廃止し、下書きPRのレビュー受付への遷移は`open-pull-request`の最後の工程が委譲する。このrepository自身が`agent-work-policy`を使うための設定fileは、委譲先が公開するinstall手順に合わせて置き換えた。互換経路は用意しない。設定の一時fileはshell終了では削除されず、返却された絶対pathを次の工程へ渡し、完了・停止時にrun-configのcleanupでそのrunだけを削除する。以前の一時fileや異なる実行identityを再利用せず、新しいrunを開始する。

検証CLIのstdoutはJSONのみとなり、commandの出力はresults[].log_pathへ移る。呼出元はstdoutをログとして連結せずJSONとして読み、失敗時のexit_codeとlog_pathを参照する。
