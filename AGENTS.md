> 作業を始める前に、workspace規約入口 `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md` を読み、そこから指定される共通規約とこのrepository固有の規則を適用する。

# AGENTS.md

このrepositoryはPull Requestの作成、競合の調査・解消、review responseを扱うmarketplaceである。marketplaceへ公開するインストール対象はpackage `pull-request`（`./plugins/pull-request`）だけにし、公開入口は `skills/open-pull-request`（平時: 検証済みbranchからPRを作る）、`skills/resolve-pr-conflicts`（例外: 競合を調査・資料化・gate・解消・検証する）、`skills/respond-to-pr-review` の3つとする。内部skillは置かない。各入口は自身の `SKILL.md`、隣接 `playbook.yml`、`references/`、`scripts/`、`assets/` だけで完結し、工程順は `playbook.yml` の宣言順が基準資料で同じagentが辿る。`open-pull-request` は競合を検出したときだけ `resolve-pr-conflicts` を `steps[].skill` で1工程として呼ぶ（同package内の内部契約）。

別repositoryへは、そのrepositoryが公開するpackageだけで依存し、`playbook.yml` の `requires` に `{plugin, marketplace}` で宣言して `playbook:` の工程でだけ呼ぶ。`skill:` や `script:` で指さない。外部packageへは公開契約の入力objectを直接渡し、同じ呼び出しが返す公開結果objectだけを使う。`agent-work-policy` には契約ID・版・対象repository・1つのactionとそのaction固有値を持つ完全なobjectを直接渡す。`write-doc` 契約v2にはobject配列の素材と排他的な保存先を直接渡す。1回の委譲で頼む操作は1つだけにする。

外部の内部skill名、工程id、script、引数、exit code、設定file、設定keyを、playbook.yml・SKILL.md・README・references・scripts・設定のどこにも書かない。公開Git操作（commit / push / PR作成 / merge）のpermissionとgateはこのrepositoryの設定fileへ置かず、`agent-work-policy` の契約に委ねる。素の `git commit` / `git push` / `gh pr create` / `gh pr merge` を配布物のscriptに書かない。

repositoryごとの方針は `<repo>/.harness-plugins/<入口>.config.yml` の1層で受け取り（1入口1設定file）、同梱既定へのfallbackと層の探索を置かない。設定の読み取りは各入口の `scripts/config.py check|read --repo <repository_path>`（stdin不要、path固定、stdoutにJSON 1文書、失敗はexit 2と `reason`）に揃え、その契約は各SKILL.mdの手順に1か所だけ書く。プロジェクト固有の文脈は対象repositoryのAGENTS.md / CLAUDE.mdと各入口の任意入力 `references`（絶対path配列）で渡す。`SKILL.md`、`references/`、`playbook.yml` に実行基盤の配管（`${.`マクロ、同期block、環境変数によるroot解決、設定解決scriptの実行指示）を書かない。

変更後は `bash scripts/validate.sh` と `bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/scripts/validate.sh /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/pull-request-plugins` を実行する。

## 検査スクリプトは、意味が一意に決まることだけを判定する

このrepositoryの検査スクリプト（validate、lint、verify、checkなど、名前を問わない）が判定してよいのは、ファイルや見出しの有無、識別子や版の一致、宣言と配置の対応、禁止された書き方の有無のように、入力と基準資料から意味が決定論的に一意に決まることだけである。読んで解釈しないと決まらないことや、件数や語の出現のような品質の代わりの指標は判定せず、エージェントが読んで評価する（意味評価）。判定が一意に決まることを宣言できない検査は作らず、詳しい条件は `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/.agents/rules/deterministic-validation.md` に従う。
