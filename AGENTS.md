> 共通の規約は /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md にある。ここには、この repository だけの規則を置く。

# pull-request

この repository は、Pull Request の作成（`open-pull-request`）、base との競合の調査と解消（`resolve-pr-conflicts`）、review comment への対応（`respond-to-pr-review`）の三つの skill を配布する。PR と Git の操作は `git` と `gh` で直接行い、skill が持つのは、エージェントが自分では外しやすい判断だけである。設定ファイル、承認の object、それを照合するスクリプトは持たない。PR を作る前に通す検証は、対象の repository の AGENTS.md が完了判定として定める command である。

## 検証の eval

三つの skill が判断を外さないかは、root の `evals/` の下のケースで確かめる。一つのケースは、手元だけの git repository を scaffold で作り、一つの入口に一つの依頼を渡す。GitHub には一切書き込まない。plugin eval はネットワークを封じないので、scaffold の repository の remote は作業場所の中の bare repository だけにし、trace に PR の作成、merge、push の command が無いことを grader で見る。GitHub へ出ないと確かめられないこと（重複の PR の実際の確認、draft からレビュー受付への移行、review への返信の投稿）は、ケースにしない。

実行は `claude plugin eval . --case <ケース> --runs 1 --ablation none --keep-temp --scaffold --allow-tools Write Edit Bash --max-cost-usd 5 --no-publish` で、repository の root から動かす。出来の採点は harness-tools の `tools/grade-eval.sh` に、ケースと、実行が残した一時ディレクトリの絶対パスを渡して行う。採点役への指示は `evals/criteria/brief.md`、成果の種類ごとの共通の条件は `evals/criteria/<種類>.md`、ケースに固有の条件は `<ケース>/grading/criteria.md`、採点役に渡す作業の前の版と依頼は `<ケース>/materials/` にある。条件を変えたら、`<ケース>/grading/calibration/` の資料に採点役をかけ、`expected.md` の判定を再現できるかを先に確かめる。同じケースの採点を並べて走らせると結果のファイル名がぶつかるので、同じケースの採点は一つずつ回す。
