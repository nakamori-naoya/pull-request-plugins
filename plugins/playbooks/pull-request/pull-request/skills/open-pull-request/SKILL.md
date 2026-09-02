---
name: open-pull-request
description: Gitの作業branchとbase branchの競合を検出し、現行実装、関連する過去の修正・commit・GitHub PRから意図を理解して解消・検証した後、Pull Requestを作成する。「コンフリクトを解消してPRを作って」「PRを作成して」と言われたときに使う。競合資料は設定により解消前の提案または解消後の実績として提示する。
---

# open-pull-request

このentryは配布形式を中立化する薄い入口である。次を実行してplugin rootを検証し、root直下の正本`SKILL.md`を全文読んで、その手順に従う。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
cat "${PLUGIN_ROOT}/SKILL.md"
```

下書きPRを内部レビュー完了後にレビュー受付へ遷移する依頼は、この入口では扱わない。同じpluginの`mark-ready-for-review`入口を使う。
