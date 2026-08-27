# AGENTS.md

このrepositoryはPull Requestの競合調査・解消・作成とreview responseを扱うmarketplaceである。作業権限とhuman gateは設定に従い、外部依存はmarketplace名とplugin名で解決する。依存versionは固定せず、解決先に必要なskillが存在することを検査する。変更後は`bash scripts/validate.sh`を実行する。
