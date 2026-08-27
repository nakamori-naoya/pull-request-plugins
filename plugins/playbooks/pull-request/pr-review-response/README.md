# pr-review-response

指定PRのreview commentを評価し、採用分だけを修正、検証、commit、pushする。工程順、許可、human gateは設定で確定し、コメントの妥当性と修正内容はLLMがsourceを読んで判断する。

## 完全設定

外部設定は`playbook.yml`を丸ごと複製して編集する。repository設定は`<repo>/.harness-plugins/pr-review-response.config.yml`、personal設定は`~/.config/harness-plugins/pr-review-response.config.yml`。値はマージしない。

```yaml
requires:
  - {plugin: pr-review-assess, marketplace: pull-request}
  - {plugin: pr-review-apply, marketplace: pull-request}
  - {plugin: pr-review-verify, marketplace: pull-request}
  - {plugin: write-doc, marketplace: write-doc}
report:
  enabled: false
  timing: before_commit
permissions:
  review_import: true
  modify: true
  commit: true
  push: true
gates:
  after_assessment: true
  before_modify: true
  after_modify: true
  before_commit: true
  before_push: true
verification:
  commands: ["git diff --check"]
git:
  remote: origin
  require_clean_start: true
  commit_message: Address accepted PR review feedback
```

permissionがfalseなら該当操作は実行しない。gateがtrueなら、明示承認を得るまで次工程へ進まない。permissionとgateをLLM判断で読み替えない。

`requires`は`plugin`と`marketplace`のidentityだけを持ち、versionは固定しない。解決時にmanifest identityと必要なskillまたはplaybookを検査する。

`report.enabled`がfalseなら資料を作らず`write-doc`も呼ばない。`write-doc@write-doc`は完全設定の依存に残す。trueなら`timing`は`after_assessment`、`before_commit`、`before_push`、`after_push`のいずれかで、該当位置にだけ資料を作る。

```yaml
requires:
  - {plugin: pr-review-assess, marketplace: pull-request}
  - {plugin: pr-review-apply, marketplace: pull-request}
  - {plugin: pr-review-verify, marketplace: pull-request}
  - {plugin: write-doc, marketplace: write-doc}
report:
  enabled: true
  timing: before_push
```

評価・修正・検証・資料化はそれぞれ自己完結skillが担う。playbookは順序、needs/provides、permission、gateだけを拘束する。

## 終了条件

- 採用0件: 修正せず評価結果を報告して終了。
- 検証失敗: commitしない。
- commit拒否: commit/pushしない。
- push拒否: local commitまでを成果として終了。
- push成功: branchとcommitを報告する。reviewへの返信・thread resolveは行わない。
