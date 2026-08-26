---
name: apply-pr-review
description: 採否を含むPR review評価JSONを検証し、acceptされた指摘だけを対象repositoryへ修正して、変更pathと変更内容を返す。「採用したレビュー指摘を直して」と言われたときに使う。評価のやり直し、commit、pushは行わない。
---

# apply-pr-review

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
