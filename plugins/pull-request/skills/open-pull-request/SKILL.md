---
name: open-pull-request
description: 検証を通した作業branchから、重複のないPull Requestを、目的と理由が読める本文でgh により作る。base branchとの競合があれば、先に競合の解消へ回す。「PRを作成して」「このbranchを検証してPRにして」と言われたときに使う。競合の調査と解消だけ、またはreview commentへの対応だけを頼まれたときは、それぞれの入口へ返す。
---

# open-pull-request

PR は `git` と `gh` で直接作る。この skill が持つのは、エージェントが自分では外しやすい判断だけである。

## 作る前に、同じ PR が無いかと、競合が無いかを確かめる

同じ head と base の open な PR が既にあれば、新しく作らない。`gh pr list --head <branch> --base <base>` で確かめ、あればその PR が今の head を指しているかを見て、番号と URL を返す。確認できなかったことを「無い」と扱わない。

base との競合は、`git merge-tree --write-tree <base> <head>` のように作業ツリーを変えない方法で確かめる。競合があれば、この入口で解かずに resolve-pr-conflicts へ回し、解消と検証が済んでから戻る。

PR を作る前に、repository が完了判定に使う検証を作業 branch で通す。通らなければ PR を作らず、失敗した command と残る問題を返す。検証の command は、作業方針の設定の `verification.commands` を記載順にすべて実行する。設定は、repository が自分の `.harness-plugins/agent-work-policy.config.yml` を持っていればその一つだけを読み、持っていなければ `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/.harness-plugins/agent-work-policy.config.yml` を読む。二つを重ねて上書きしない。どちらも無ければ、検証を推測で選ばずに止まる。

## 本文には、何をなぜ変えたかを文章で書く

本文は、読み手が変更を受け入れるかを判断するためにある。何を、なぜ変えたか、既知の制約がなぜ生じるかを段落の文章で書く。見出しごとに箇条書きを並べる雛形にしない。箇条書きは、実行した検証の一覧のような本当の並列と、確かめる手順にだけ使う。競合を解いた場合は、その方針も書く。秘密値、手元のパス、一時ファイルは本文に入れない。

## レビュー受付へ移すのは、内部レビューが済んだと明示されてから

draft の PR をレビュー受付へ移すのは、利用者か manager が内部レビューの完了を明示した後だけである。作った直後に無条件で外さない。PR を作っても merge はしない。merge と base への追従は、agent-work-policy の規律に従う。
