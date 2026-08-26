---
name: respond-to-pr-review
description: 指定GitHub PRのreview commentを取得・評価し、人間gateで採否を確認して、採用分だけを修正・検証・commit・pushする。「PRレビューを取り込んで」「指摘を直してpushして」と言われたときに使う。許可とgateは設定どおりに扱い、reviewへの返信やresolveはしない。
---

# respond-to-pr-review

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
