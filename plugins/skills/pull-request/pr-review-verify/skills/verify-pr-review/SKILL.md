---
name: verify-pr-review
description: repositoryと検証command一覧を受け取り、PR review修正を順番どおり検証して成否を返す。「レビュー修正を検証して」と言われたときに使う。source変更、commit、pushは行わない。
---

# verify-pr-review

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
