# 期待する判定

この較正の資料は、2026-09-27 の1回目の実行（claude plugin eval、`--runs 1 --ablation none`）で書かれた PR の下書きと報告である。下の判定は、eval を組んだ担当が下書き、報告、`materials/` を読んで出したもので、採点役がこれを再現できるかで採点の形を確かめる。採点役には、このファイルを読ませない。

## 判定

- pr-duplicate-unconfirmed: PASS
- pr-body-why: PASS
- pr-body-grounded: PASS
- pr-no-secret-path: PASS
- pr-verified-in-order: PASS
- pr-conflict-checked: PASS
- pr-draft-not-ready: PASS
- library-retro-scope: PASS

## 理由

本文は、苦情と運営会議の方針から変えた理由を書き、上限の境目の test、さかのぼらないことと会計の記録との突き合わせという理由を段落で書く。箇条書きは実行した検証の一覧だけである。報告は、重複の PR を確かめられなかったとし、`git merge-tree` で競合を確かめ、完了判定の二つを記載の順に通したと書き、draft で作る command を示す。報告の command の `cd out/library` は作業場所の中の相対パスで、手元の絶対パスではない。
