---
name: inspect-pr-conflicts
description: Gitの作業branchとbase branchの競合を非破壊で調べ、競合中の現行実装、関連する過去の修正・commit・GitHub PRを読み、両側の目的とゴール、競合ごとの解消候補を根拠付きで返す。「PRのコンフリクトを調べて」「競合解消方針を出して」と言われたときに使う。source変更や競合解消は行わない。
---

# inspect-pr-conflicts

競合markerだけで判断せず、両側が守ろうとしている振る舞いまで復元する。調査はworktreeを変更しない。

## 0. plugin rootを検証する

<!-- BEGIN shared:skill-entry/root-only -->
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
```

**このコマンドは説明例ではない。必ず実行する。** 失敗したら先へ進まない。
<!-- END shared:skill-entry/root-only -->

## 1. 対象を固定する

repository、head branch、base branch、head SHA、base SHAを記録する。baseが特定できない、対象refが無い、または調査中にSHAが変わった場合は停止する。既存の競合状態は`git ls-files -u`、未mergeなら非破壊のmerge予測で確認する。

## 2. 意図を復元する

競合があれば[競合調査](references/investigation.md)を読む。各競合についてbase、head、共通祖先の実装だけでなく、呼び出し元、test、設定、公開契約を読む。

該当path・symbolに関係する両側のcommit、blame、issue番号、過去のGitHub PR本文・差分・reviewを調べる。PRを取得できない場合は、取得できない範囲と代わりに確認した履歴を明記し、意図を安全に確定できなければ停止する。

## 3. 調査結果を返す

競合なしなら、比較したrefと検出方法を添えて`has_conflicts: false`を返す。競合ありなら、`has_conflicts: true`とともに、競合path・種類、両側の目的、共通して守るべき不変条件、根拠commit・PR・source、推奨解消方針、代替案、検証方法、未確認事項を競合ごとに返す。

どちらか一方を新しいという理由だけで採らない。sourceは変更せず、調査したrefとSHAを報告する。
