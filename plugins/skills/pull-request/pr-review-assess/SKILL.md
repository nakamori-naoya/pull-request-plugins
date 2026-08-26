---
name: assess-pr-review
description: 指定されたGitHub PRのreview commentをMCPで取得し、関連source・diff・履歴から意図を復元して、コメントごとの妥当性・採否・理由を構造化して返す。「PRレビューを精査して」「この指摘を採用すべきか見て」と言われたときに使う。source修正やreviewへの返信は行わない。
---

# assess-pr-review

review commentを票として数えず、sourceの不変条件と変更意図に照らして採否を決める。評価結果は後から人間が検証できる根拠を持たせる。

## 0. plugin rootを検証する

<!-- BEGIN shared:skill-entry/root-only -->
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
```

**このコマンドは説明例ではない。必ず実行する。** 失敗したら先へ進まない。
<!-- END shared:skill-entry/root-only -->

## 1. PRとreview commentを取得する

GitHub MCPで指定PRのmetadata、diff、review、inline comment、未解決threadを取得する。MCPが使えなければ停止し、取得できていない範囲を成功扱いしない。reviewへの返信・resolveはしない。

## 2. 意図を復元して評価する

[評価基準](references/evaluation.md)を読む。各commentについて、対象行だけでなく関連関数、呼び出し元、test、履歴を読み、元の変更意図と不変条件を復元する。

`accept` / `reject` / `defer`を選び、comment本文、対象位置、復元した意図、根拠、想定修正、検証方法を記録する。判断内容はscriptへ委ねない。

## 3. 構造化して検証する

[出力schema](references/assessment-schema.md)に従い`assessment.json`を作る。

```bash
python3 "${PLUGIN_ROOT}/scripts/assessment.py" validate --file /path/to/assessment.json
```

schema不正なら完了としない。0件なら「review comment 0件」と明記する。
