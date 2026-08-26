# pr-conflict-resolve

作業branchとbase branchの競合を、両側の現行実装、関連commit、過去のGitHub PRで目的とゴールを確認してから解消し、検証済みの統合結果を返す。

## 入力

- Git repository、head、base、統合方法
- 必要なら既存の競合調査結果
- 実行すべき検証command
- repositoryが定める変更・commitの権限とgate

## 出力

競合path、両側の目的、採用方針、修正内容、根拠、検証結果、作成したcommit、未確認事項を返す。PR自体は作成しない。

## 停止条件

- 調査結果のSHAまたは競合集合が現在状態と一致しないまま再調査できない
- 両側のゴールが両立せず、仕様上の選択が必要
- 関連履歴やPRを取得できず、安全に意図を確定できない
- unmerged entry、競合marker、検証失敗が残る

設定ファイルは持たない。
