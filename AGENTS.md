> 作業を始める前に、workspace正本入口 `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md` を読み、そこから指定される共通規約とこのrepository固有の規則を適用する。

# AGENTS.md

このrepositoryはPull Requestの競合調査・解消・作成とreview responseを扱うmarketplaceである。marketplaceへ公開するインストール対象は`pull-request` playbook packageだけにし、個々のplaybookと下段skillを別entryへ公開しない。作業権限とhuman gateは設定に従う。

別repositoryへは、そのrepositoryが公開するplaybookだけで依存する。stepでは外部pluginを`playbook:`でしか指さず、`skill:`や`script:`で指さない。公開契約が設定解決を要求する依存は`${.deps.<論理依存名>.root}`の公開入口と`${.deps.<論理依存名>.entry}`だけを使う。直接入出力を定める`write-doc`契約v2は`${.deps.write-doc.entry}`へ契約入力を直接渡す。skill名で入口を指す形とブラケット形は書かない。

呼び出し方は依存先の公開契約に従う。`agent-work-policy`は入力YAMLを作って設定を一度だけ解決し、その公開出力を読む。`write-doc`契約v2はobject配列の素材と明示した保存先を直接渡し、`status`と`path`または`reason`を直接受け取る。1回の委譲で頼む操作は1つだけにする。

外部の内部skill名、工程id、script、引数、exit code、設定ファイル、設定キーを、playbook.yml・SKILL.md・README・references・scripts・設定のどこにも書かない。

依存versionは固定せず、解決先のmanifest identityと公開playbookの存在を検査する。変更後は`bash scripts/validate.sh`を実行する。
