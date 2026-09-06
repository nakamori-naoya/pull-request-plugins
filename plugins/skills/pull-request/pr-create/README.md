# pr-create

Git branchの差分、commit、検証結果、既存PRを確認し、重複のないGitHub Pull Requestのtitleとbodyを組み立てる。実装変更、競合解消、push、Pull Request作成そのものは責務外である。

## 入力

- Git repository、head branch、PR title/bodyに必要な情報
- 呼び出し元が渡す作業場所の値（base branch、remote、下書き設定、作業branch）と、確認できていれば開いているPR番号
- PR titleとbodyへ反映する目的、変更、検証結果、未確認事項
- 任意で競合解消結果と詳細資料の参照

## 出力

title、bodyを書いたファイルの絶対path、head/base、remote、下書き設定、検証結果、競合解消の有無、未確認事項を返す。同じhead/baseのopen PRがあれば新規作成を要求せず、既存PRのnumberとURLを返す。

## 停止条件

- base branch、remote、下書き設定、作業branchのいずれかが入力として渡されていない
- 記録されたhead SHAが現在値と食い違う、または競合が残っている
- 必須検証が失敗または未実行
- 差分やcommitを読めず、目的と変更を本文へ書けない

設定ファイルは持たない。**作業場所の値は呼び出し元が渡した入力からだけ受け取り、他所の設定を読まない。**
