---
name: mark-ready-for-review
description: 内部レビューが完了した下書きPull Requestを、Agent Work Policyへ委譲してレビュー受付へ遷移する。「この下書きPRをレビュー可能にして」と依頼されたときに使う。PR作成、merge、review responseは行わない。
---

# mark-ready-for-review

この入口は`open-pull-request` playbookとは独立している。PR作成直後には使わず、利用者またはmanagerが内部レビュー完了を明示した後、merge readinessを確認する前にだけ実行する。

## 1. 明示入力を確認する

次の3つが全て明示されなければ停止する。

- PR番号
- Agent Work Policyの解決済み依存root
- 内部レビュー完了の宣言

依存rootのversionは比較しない。`scripts/prepare.sh`、`scripts/control.py`、および`control.py --help`に`ready-for-review` commandがあることだけを確認する。欠ける場合は公開操作をせず停止する。

## 2. Agent Work Policyへ委譲する

このplugin rootの`$PLUGIN_ROOT`を決め、次を実行する。`--policy-root VALUE`と`--policy-root=VALUE`、`--repo VALUE`と`--repo=VALUE`、`--pr VALUE`と`--pr=VALUE`のどちらも受け付ける。

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/pull-request}"
bash "$PLUGIN_ROOT/scripts/ready-for-review.sh" \
  --policy-root "$POLICY_ROOT" --repo "$(pwd)" --pr "$PR_NUMBER" \
  --internal-review-complete
```

scriptはPolicyの`prepare.sh`で対象repositoryの設定を解決し、`control.py ready-for-review`へ委譲する。permission、human gate、PRのhead/base照合、下書き判定、`gh`操作をこのskillやscriptで再実装しない。

Policyが`{status:"ready", changed:true}`を返せば下書きをレビュー受付へ遷移した事実、`changed:false`を返せば既に公開済みで外部変更が無かった事実を記録する。Policyが失敗した場合はmerge readinessへ進まない。

## 3. 報告する

PR番号、Policyが返した`changed`、停止理由、未実行操作を報告する。PR作成、merge、review responseはこの入口の責務外である。
