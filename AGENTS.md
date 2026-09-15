> 作業を始める前に、workspace正本入口 `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md` を読み、そこから指定される共通規約とこのrepository固有の規則を適用する。

# AGENTS.md

このrepositoryはPull Requestの競合調査・解消・作成とreview responseを扱うmarketplaceである。marketplaceへ公開するインストール対象は`pull-request` playbook packageだけにし、個々のplaybookと下段skillを別entryへ公開しない。作業権限とhuman gateは設定に従う。

別repositoryへは、そのrepositoryが公開するplaybookだけで依存する。stepでは外部pluginを`playbook:`でしか指さず、`skill:`や`script:`で指さない。外部packageへは公開契約の入力objectを直接渡し、同じ呼び出しが返す公開結果objectだけを使う。

呼び出し方は依存先の公開契約に従う。`agent-work-policy`には契約ID・版・対象repository・1つのactionとそのaction固有値を持つ完全なobjectを直接渡す。`write-doc`契約v2にはobject配列の素材と排他的な保存先を直接渡し、`status`と`path`または`reason`を直接受け取る。1回の委譲で頼む操作は1つだけにする。

外部の内部skill名、工程id、script、引数、exit code、設定ファイル、設定キーを、playbook.yml・SKILL.md・README・references・scripts・設定のどこにも書かない。

依存versionは固定せず、解決先のmanifest identityと公開playbookの存在を検査する。変更後は`bash scripts/validate.sh`を実行する。
