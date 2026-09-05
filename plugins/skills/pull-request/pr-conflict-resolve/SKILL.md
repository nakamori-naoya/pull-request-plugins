---
name: resolve-pr-conflicts
description: Gitの作業branchとbase branchの競合について、現行実装、関連する過去の修正・commit・GitHub PRから両側の目的とゴールを理解し、意味を保つ実装へ解消して検証結果を返す。「PRのコンフリクトを解消して」「merge conflictを直して」と言われたときに使う。PR作成は行わない。
---

# resolve-pr-conflicts

競合を消すことではなく、両側の目的とrepositoryの不変条件を満たす統合を完了させる。

## 0. plugin rootを検証する

<!-- BEGIN shared:skill-entry/root-only -->
```bash
BUNDLE_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
if [ -d "${BUNDLE_ROOT}/skills/pull-request/pr-conflict-resolve" ]; then
  PLUGIN_ROOT="${BUNDLE_ROOT}/skills/pull-request/pr-conflict-resolve"
else
  PLUGIN_ROOT="${BUNDLE_ROOT}"
fi
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
```

**このコマンドは説明例ではない。必ず実行する。** 失敗したら先へ進まない。
<!-- END shared:skill-entry/root-only -->

## 1. 状態と権限を確定する

repository規範を読み、base、head、統合方法、許可された変更・commit操作、検証commandを確定する。無関係な未commit変更、別の進行中merge、base不明、必要な操作権限不足があれば停止する。

調査結果を受け取った場合も、記録されたSHAと現在SHA、競合集合を照合する。ずれていれば古い方針で進めず、現在状態を再調査する。

## 2. 意味を確認して解消する

[解消判断](references/resolution.md)を読む。各競合についてbase、head、共通祖先、関連source・test・設定・公開契約を読み、関連commitと過去のGitHub PR本文・差分・reviewから両側の目的とゴールを確認する。取得不能範囲を隠さず、安全に判断できなければ変更しない。

片側の一括採用ではなく、守るべき振る舞いから統合結果を実装する。生成物は入力を統合して正規commandで再生成する。解消対象外の整理を混ぜない。

## 3. 検証する

unmerged entryが0件であること、競合markerが残らないこと、解消diffが調査した目的と一致することを確認する。指定された検証commandを記載順に全件実行する。失敗時は完了にせず、再現commandと残る問題を返す。

## 4. 報告する

競合pathと種類、両側の目的、採った方針、実際の修正、根拠commit・PR・source、検証結果、作成したcommit、未確認事項を返す。確認できなかった履歴やPRを確認済みとして扱わない。
