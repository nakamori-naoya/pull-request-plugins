---
name: inspect-pr-conflicts
description: Gitの作業branchとbase branchの競合を非破壊で調べ、競合中の現行実装、関連する過去の修正・commit・GitHub PRを読み、両側の目的とゴール、競合ごとの解消候補を根拠付きで返す。「PRのコンフリクトを調べて」「競合解消方針を出して」と言われたときに使う。source変更や競合解消は行わない。
---

# inspect-pr-conflicts

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
