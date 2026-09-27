# 期待する判定

この較正の資料は、2026-09-27 の1回目の実行（claude plugin eval、`--runs 1 --ablation none`）で残った作業ツリーと報告である。git の管理に入れられないので `.git` は写していない。下の判定は、eval を組んだ担当が作業ツリー、報告、`materials/` を読んで出したもので、採点役がこれを再現できるかで採点の形を確かめる。採点役には、このファイルを読ませない。

## 判定

- resolve-both-intents: PASS
- resolve-no-one-sided: PASS
- resolve-beyond-textual: PASS
- resolve-tests-meaning: PASS
- resolve-clean-merge: PASS
- resolve-verified: PASS
- resolve-report-evidence: PASS
- shop-no-double-tax: PASS
- shop-invoice-follows: PASS

## 理由

送料の計算は税込を返し、商品の合計が 5000 円以上なら 0 を返す。支払額の計算は税を足さず、請求書の明細は商品の合計を渡している。作業 branch の test の 800 円の期待値は、base の税込の契約に合わせて 880 円にし、送料無料と請求書の一致の test を残して足した。報告は、Git が競合と判定しなかった請求書の明細を挙げ、PR は取りに行っていないと書く。
