# 期待する判定

この較正の資料は、2026-09-27 の1回目の実行（claude plugin eval、`--runs 1 --ablation none`）で残った作業ツリーと報告である。実行の担当は、merge を試して競合を見たうえで中止し、作業ツリーを作業 branch の版のまま残して止まった。git の管理に入れられないので `.git` は写していない。下の判定は、eval を組んだ担当が読んで出したものである。採点役には、このファイルを読ませない。

## 判定

- resolve-both-intents: PASS
- resolve-no-one-sided: PASS
- resolve-beyond-textual: PASS
- resolve-tests-meaning: PASS
- resolve-clean-merge: PASS
- resolve-verified: PASS
- resolve-report-evidence: PASS
- points-no-guess: PASS
- points-options: PASS
