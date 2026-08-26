---
name: apply-pr-review
description: 採否を含むPR review評価JSONを検証し、acceptされた指摘だけを対象repositoryへ修正して、変更pathと変更内容を返す。「採用したレビュー指摘を直して」と言われたときに使う。評価のやり直し、commit、pushは行わない。
---

# apply-pr-review

入力に列挙された採用指摘だけを修正し、無関係な整理を混ぜない。

## 0. プラグイン root を決める

<!-- BEGIN shared:skill-entry/root-only -->
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
```

**このコマンドは説明例ではない。必ず実行する。** 失敗したら先へ進まない。
<!-- END shared:skill-entry/root-only -->

## 1. 実行

```bash
python3 "${PLUGIN_ROOT}/scripts/brief.py" --assessment /path/to/assessment.json --out /tmp/fix-brief.md
```

[入力と変更契約](references/contract.md)を読み、評価JSONの全必須fieldと対象repositoryを検査する。`accept`が0件なら変更せず終了する。

briefの対象だけをsourceとtestへ反映する。変更後にdiffを照合し、採用されていない変更があれば完了にしない。成果として変更path一覧とcomment別変更内容を返す。commit、push、review返信はしない。
