---
name: respond-to-pr-review
description: 指定したGitHub PRのreview commentを、sourceの不変条件と変更の意図に照らしてaccept・reject・deferに分け、採否を利用者に確かめてから、採用分だけを直して検証する。「このPRのレビューに対応して」「review commentを評価して直して」と言われたときに使う。reviewへの返信とthreadのresolveは、利用者が頼んだときだけ行う。
---

# respond-to-pr-review

review comment は、書かれたとおりに直す指示ではない。source と test に照らして正しいかを確かめ、採るものだけを直す。

## comment ごとに、根拠で accept、reject、defer に分ける

PR の本文と diff から変更の目的を取り、comment が指す行を含む関数、型、test を読み、呼び出し元と近くの不変条件を読む。意図した設計なのか偶然の実装なのかが分からなければ、履歴で確かめる。

再現できる欠陥、契約の違反、保守上の明確な損失を指摘していて、変更の目的を壊さずに直せるものだけを accept にする。source や test と矛盾する、既存の契約を壊す、好みだけである、既に満たされている、のどれかなら reject にする。仕様、権限、外部の状態が足りず安全に決められないものは defer にし、何が分かれば決められるかを書く。defer を reject に丸めない。reviewer の人数、肩書、断定の強さでは決めない。反対するときも、根拠にした source と観測を残す。

## 採否を利用者に確かめてから直す

評価を示し、採否を利用者に確かめる。reviewer と実装者のどちらの意図を優先するかは、エージェントが決めてよいことではないからである。accept が 0 件なら何も変えず、reject と defer の根拠を報告して終える。

直すのは、確かめた accept の comment だけである。reject と defer、評価に無い改善、書式の一括変更を混ぜない。直した後に diff を評価と照らし、採っていない変更が混ざっていれば先へ進まない。repository が完了判定に使う検証を通してから commit する。commit と push は `git` で直接行い、agent-work-policy の規律に従う。

報告には、comment ごとの採否と根拠、変えたファイル、検証の結果、commit と push の結果を書く。review への返信と thread の resolve は GitHub に書き込む操作なので、利用者が頼んだときだけ行う。
