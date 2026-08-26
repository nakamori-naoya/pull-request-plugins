---
name: assess-pr-review
description: 指定されたGitHub PRのreview commentをMCPで取得し、関連source・diff・履歴から意図を復元して、コメントごとの妥当性・採否・理由を構造化して返す。「PRレビューを精査して」「この指摘を採用すべきか見て」と言われたときに使う。source修正やreviewへの返信は行わない。
---

# assess-pr-review

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
