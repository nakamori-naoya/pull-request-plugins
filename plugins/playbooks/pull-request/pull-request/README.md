# pull-request

作業branchの競合を現行実装、関連commit、過去のGitHub PRから調査し、必要なら意味に基づいて解消・検証してからPull Requestを作成する。

競合がある場合の資料は、解消前の提案と解消後の実績のどちらで提示するかを設定で選べる。解消前を選ぶと、資料を提示した後は利用者の明示承認まで停止する。競合が無ければ競合資料は作らない。

## 設定

設定候補はrepositoryの`.harness-plugins/pull-request.config.yml`、personalの`~/.config/harness-plugins/pull-request.config.yml`、同梱`playbook.yml`の順で1ファイルだけを選ぶ。部分設定はマージしないため、外部設定は同梱`playbook.yml`全体を複製して使う。

選択する値は次の2つである。

```yaml
conflict_report:
  timing: before_resolution  # 解消案を提示し、利用者の明示承認後に解消する
```

```yaml
conflict_report:
  timing: after_resolution   # 解消後に競合、方針、修正、検証を資料化して示す
```

[同梱の完全設定](playbook.yml)には`version`、`name`、`description`、`instructions`、`requires`、`conflict_report`、`git`、`pull_request`、`verification`、`steps`が必要である。`git.base_branch`、`git.remote`、`pull_request.draft`、`verification.commands`も対象repositoryに合わせる。

## 入力と出力

入力はGit repository、作業branch、PR title/bodyに必要な目的と変更内容である。出力はPR URLとnumber、head/base、競合の有無、調査根拠、解消内容、検証結果、選択した時点の資料参照、未確認事項である。

## 停止条件

- base、head、remoteを特定できない
- 関連履歴や過去PRを調べられず、安全に競合方針を決められない
- 現在SHAまたは競合集合が調査結果から変わった
- 競合、marker、検証失敗が残る
- repositoryのpermissionまたはhuman gateを満たさない

必要plugin: `pr-conflict-inspect@pull-request`、`pr-conflict-resolve@pull-request`、`pr-create@pull-request`、`write-doc@write-doc`。versionは固定せず、解決先のmanifest identityと必要なskillまたはplaybookを検査する。
