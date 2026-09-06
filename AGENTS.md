# AGENTS.md

このrepositoryはPull Requestの競合調査・解消・作成とreview responseを扱うmarketplaceである。marketplaceへ公開するインストール対象は`pull-request` playbook packageだけにし、個々のplaybookと下段skillを別entryへ公開しない。作業権限とhuman gateは設定に従う。

別repositoryへは、そのrepositoryが公開するplaybookだけで依存する。stepでは外部pluginを`playbook:`でしか指さず、`skill:`や`script:`で指さない。解決結果から組み立ててよいのは`${.deps.<論理依存名>.root}`の直下3点（`scripts/prepare.sh`、`playbook.yml`、`scripts/resolve.sh`）と、入口`SKILL.md`の絶対pathである`${.deps.<論理依存名>.entry}`の**2形だけ**である。skill名で入口を指す形とブラケット形は書かない。

呼び出しは2段にする。自分が`prepare.sh --input --scope --bindings`で実行設定を解決し、得た絶対pathを入口`SKILL.md`へ渡して実行させ、入力に書いた書き込み先から公開出力を受け取る。依存先に`prepare.sh`を実行し直させない。1回の委譲で頼む操作は1つだけにし、その操作が使わないキーは入力に書かない。

外部の内部skill名、工程id、script、引数、exit code、設定ファイル、設定キーを、playbook.yml・SKILL.md・README・references・scripts・設定のどこにも書かない。

依存versionは固定せず、解決先のmanifest identityと公開playbookの存在を検査する。変更後は`bash scripts/validate.sh`を実行する。
