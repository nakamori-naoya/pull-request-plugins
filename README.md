# Pull Request

Pull Requestの競合調査・解消・作成と、reviewの評価・修正・検証・公開を扱うClaude Code/Codex両対応marketplaceである。

## インストール済みである必要があるplugin

- `pull-request@pull-request`: `pr-conflict-inspect@pull-request`、`pr-conflict-resolve@pull-request`、`pr-create@pull-request`、`write-doc@write-doc`
- `pr-review-response@pull-request`: `pr-review-assess@pull-request`、`pr-review-apply@pull-request`、`pr-review-verify@pull-request`、`write-doc@write-doc`
- 下段の各skill plugin: 追加依存なし

## 検証

```bash
bash scripts/validate.sh
```
