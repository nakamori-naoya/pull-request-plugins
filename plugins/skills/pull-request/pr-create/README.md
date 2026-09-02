# pr-create

Git branchの差分、commit、検証結果、既存PRを確認し、必要なpushを行って重複のないGitHub Pull Requestを作成する。実装変更や競合解消は責務外である。

## 入力

- Git repository、head branch、PR title/bodyに必要な情報
- 呼び出し元が解決した`--policy-root`（Agent Work Policyの依存root）
- PR titleとbodyへ反映する目的、変更、検証結果、未確認事項
- 任意で競合解消結果と詳細資料の参照

## 出力

PR numberとURL、head/base、push先、title、検証結果、競合解消の有無、draft状態、未確認事項を返す。同じhead/baseのopen PRがあれば新規作成せず既存PRを返す。

## 停止条件

- `--policy-root`が無い、またはAgent Work Policyの`prepare.sh` / `control.py`を持たない
- Agent Work Policyがdetached HEAD、baseへの直接push、unmerged entry、対象外の未commit変更を停止した
- 必須検証が失敗または未実行
- permissionが無い、必要なhuman gateを通っていない
- pushまたはGitHub PR作成手段を利用できない

設定ファイルは持たない。公開方針は呼び出し元が渡したAgent Work Policy rootだけから解決する。
