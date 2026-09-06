# pr-review-response

指定PRのreview commentを評価し、採用分だけを修正、検証する。コメントの妥当性と修正内容はLLMがsourceを読んで判断し、commit/pushの許可・gate・実行は`agent-work-policy`へ委譲する。

## 完全設定

外部設定は`playbook.yml`を丸ごと複製して編集する。repository設定は`<repo>/.harness-plugins/pr-review-response.config.yml`、personal設定は`~/.config/harness-plugins/pr-review-response.config.yml`。値はマージしない。

```yaml
requires:
  - {plugin: pr-review-assess, marketplace: pull-request}
  - {plugin: pr-review-apply, marketplace: pull-request}
  - {plugin: pr-review-verify, marketplace: pull-request}
  - {plugin: write-doc, marketplace: write-doc}
  - {plugin: agent-work-policy, marketplace: agent-work-policy}
report:
  enabled: false
  timing: before_commit
permissions:
  review_import: true
  modify: true
gates:
  after_assessment: true
  before_modify: true
  after_modify: true
verification:
  commands: ["git diff --check"]
git:
  require_clean_start: true
  commit_message: Address accepted PR review feedback
```

この設定のpermissionがfalseならreview取込・修正を実行しない。gateがtrueなら、明示承認を得るまで次工程へ進まない。commit/pushはこの設定で判断せず、`agent-work-policy`の公開playbookへ1呼び出し1操作で委譲し、その公開出力だけを読む。

`requires`は`plugin`と`marketplace`のidentityだけを持ち、versionは固定しない。解決時にmanifest identityと公開playbookの存在を検査する。外部の`write-doc`と`agent-work-policy`は公開playbookとしてだけ使い、その入口・入力・出力・保証以外には依存しない。

`report.enabled`がfalseなら資料を作らず`write-doc`も呼ばない。`write-doc@write-doc`は完全設定の依存に残す。trueなら`timing`は`after_assessment`、`before_commit`、`before_push`、`after_push`のいずれかで、該当位置にだけ資料を作る。

```yaml
requires:
  - {plugin: pr-review-assess, marketplace: pull-request}
  - {plugin: pr-review-apply, marketplace: pull-request}
  - {plugin: pr-review-verify, marketplace: pull-request}
  - {plugin: write-doc, marketplace: write-doc}
  - {plugin: agent-work-policy, marketplace: agent-work-policy}
report:
  enabled: true
  timing: before_push
```

評価・修正・検証はそれぞれ自己完結skillが担い、資料化と公開Git操作は外部の公開playbookへ委譲する。playbookはreview固有の順序、needs/provides、permission、gateだけを拘束する。

## 互換性と移行上の注意

公開操作は委譲先が許すbranchでだけ実行される。人間が作成した既存PRのbranchでreview対応を行う場合、委譲先が受け付けなければそこで停止する。既存の`pr-review-response.config.yml`に削除済みの`permissions.commit`、`permissions.push`、`gates.before_commit`、`gates.before_push`、`git.remote`が残る場合も、未知キーとしてfail closedする。

## 終了条件

- 採用0件: 修正せず評価結果を報告して終了。
- 検証失敗: commitしない。
- commit拒否: commit/pushしない。
- push拒否: local commitまでを成果として終了。
- push成功: branchとcommitを報告する。reviewへの返信・thread resolveは行わない。
