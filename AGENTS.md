> 作業を始める前に、workspace正本入口 `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md` を読み、そこから指定される共通規約とこのrepository固有の規則を適用する。

# AGENTS.md

このrepositoryはPull Requestの競合調査・解消・作成とreview responseを扱うmarketplaceである。marketplaceへ公開するインストール対象はpackage `pull-request`（`./plugins/pull-request`）だけにし、公開入口は `skills/open-pull-request` と `skills/respond-to-pr-review` の2つとする。内部skillは置かない。各入口は自身の `SKILL.md`、隣接 `playbook.yml`、`references/`、`scripts/`、`assets/` だけで完結し、工程順は `playbook.yml` の宣言順が正本で同じagentが辿る。

別repositoryへは、そのrepositoryが公開するpackageだけで依存し、`playbook.yml` の `requires` に `{plugin, marketplace}` で宣言して `playbook:` の工程でだけ呼ぶ。`skill:` や `script:` で指さない。外部packageへは公開契約の入力objectを直接渡し、同じ呼び出しが返す公開結果objectだけを使う。`agent-work-policy` には契約ID・版・対象repository・1つのactionとそのaction固有値を持つ完全なobjectを直接渡す。`write-doc` 契約v2にはobject配列の素材と排他的な保存先を直接渡す。1回の委譲で頼む操作は1つだけにする。

外部の内部skill名、工程id、script、引数、exit code、設定file、設定keyを、playbook.yml・SKILL.md・README・references・scripts・設定のどこにも書かない。公開Git操作（commit / push / PR作成 / merge）のpermissionとgateはこのrepositoryの設定fileへ置かず、`agent-work-policy` の契約に委ねる。素の `git commit` / `git push` / `gh pr create` / `gh pr merge` を配布物のscriptに書かない。

repositoryごとの方針は `<repo>/.harness-plugins/<入口>.config.yml` の1層で受け取り、同梱既定へのfallbackと層の探索を置かない。`SKILL.md`、`references/`、`playbook.yml` に実行基盤の配管（`${.`マクロ、同期block、環境変数によるroot解決、設定解決scriptの実行指示）を書かない。

変更後は `bash scripts/validate.sh` と `bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/scripts/validate.sh /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/pull-request-plugins` を実行する。
