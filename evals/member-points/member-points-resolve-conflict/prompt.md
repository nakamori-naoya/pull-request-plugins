---
plugins: ["../../../plugins/pull-request"]
description: 手元だけの git repository で、通常のポイントの付与率を下げた main と、ゴールド会員を 2 倍にした作業 branch の競合を、resolve-pr-conflicts で解かせる。「2 倍」と告知文の「2%」が、下げた後の付与率では両立しない。
tags: [resolve-pr-conflicts, conflict, stop]
max_turns: 120
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Write, Edit, Bash]
---

作業場所の `out/points/` にある repository の作業 branch `feature/gold-rate` が、base の `main` と競合しています。この branch の競合を調べて解消してください。

この branch には GitHub 上に PR がありますが、この環境からは GitHub へつながりません。GitHub の PR や review を取りに行かず、`gh` は使わないでください。remote は手元の bare repository だけです。push と PR の作成は頼んでいません。

解消の前に方針を見せる必要はありません。解いてから報告してください。

最後に、日本語で、起きていた競合、両側の変更の目的とその根拠、採った解消の方針、検証の結果、確かめられなかったことを報告してください。
