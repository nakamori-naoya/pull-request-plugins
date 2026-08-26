---
name: create-pull-request
description: Gitの作業branchについてrepository規範、差分、commit、検証結果、既存PRを確認し、必要なpushを行って重複のないGitHub Pull Requestを作成しURLを返す。「PRを作って」「pull requestを作成して」と言われたときに使う。実装変更や競合解消は行わない。
---

# create-pull-request

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```
