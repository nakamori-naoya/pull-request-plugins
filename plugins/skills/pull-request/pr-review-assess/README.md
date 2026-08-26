# pr-review-assess

指定PRのreview commentをGitHub MCPから取得し、関連source、diff、履歴と照合して、コメントごとの採否と理由をJSONへ残す。

このpluginは評価までを担い、source修正、commit、pushは行わない。取得先へ書き戻さず、review commentの解決や返信もしない。

## 出力契約

`assessment.json`は`references/assessment-schema.md`の形を持つ。`accept`は妥当で修正対象、`reject`は採用しない、`defer`は追加情報または人間判断が必要という意味である。票数やreviewerの肩書だけで決めない。

```bash
python3 scripts/assessment.py validate --file /path/to/assessment.json
```

成功はexit 0、schema不正はexit 2。review commentが0件でも正常な評価結果として扱う。
