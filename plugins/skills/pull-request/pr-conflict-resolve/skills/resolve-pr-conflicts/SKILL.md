---
name: resolve-pr-conflicts
description: Gitの作業branchとbase branchの競合について、現行実装、関連する過去の修正・commit・GitHub PRから両側の目的とゴールを理解し、意味を保つ実装へ解消して検証結果を返す。「PRのコンフリクトを解消して」「merge conflictを直して」と言われたときに使う。PR作成は行わない。
---

# resolve-pr-conflicts

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
