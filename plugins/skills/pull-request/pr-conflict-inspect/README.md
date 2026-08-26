# pr-conflict-inspect

作業branchとbase branchの競合を非破壊で調査し、両側の現行実装、関連commit、過去のGitHub PRから目的とゴールを復元する。競合ごとの根拠、推奨解消方針、検証方法を返す。

## 入力

- Git repository
- head branchまたはhead SHA
- base branchまたはbase SHA
- GitHub PRを調べられる認証済み手段

## 出力

競合の有無、比較したSHA、競合pathと種類、両側の目的、守るべき不変条件、関連source・commit・PR、推奨方針、代替案、検証方法、未確認事項を返す。sourceは変更しない。

## 停止条件

- baseまたはheadを特定できない
- 調査中に対象SHAが変わった
- 関係する実装や履歴を取得できず、意図を安全に確定できない

設定ファイルは持たない。
