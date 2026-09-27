---
plugins: ["../../../plugins/pull-request"]
description: 手元だけの git repository の作業 branch を main への PR にする依頼を、open-pull-request で受けさせる。GitHub へはつながらないので、PR の title と本文を下書きのファイルに書かせる。
tags: [open-pull-request, pr-draft]
max_turns: 100
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Write, Edit, Bash]
---

作業場所の `out/library/` にある repository の作業 branch `feature/overdue-cap` を、`main` への PR にしてください。

ただし、この環境からは GitHub へつながりません。remote は手元の bare repository だけです。`gh` は使わず、GitHub には何も作らないでください。PR を作る代わりに、`gh pr create` に渡すつもりの title と本文を `out/pr-draft.md` に書き、PR を作るときに実行するつもりの command を報告に書いてください。

最後に、日本語で、確かめたこと、確かめられなかったこと、下書きの path、PR を作るときの command を報告してください。
