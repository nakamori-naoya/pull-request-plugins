> 共通の規約は /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md にある。ここには、この repository だけの規則を置く。

# pull-request

この repository は、Pull Request の作成（`open-pull-request`）、base との競合の調査と解消（`resolve-pr-conflicts`）、review comment への対応（`respond-to-pr-review`）の三つの skill を配布する。PR と Git の操作は `git` と `gh` で直接行い、skill が持つのは、エージェントが自分では外しやすい判断だけである。設定ファイル、承認の object、それを照合するスクリプトは持たない。PR を作る前に通す検証は、対象の repository の AGENTS.md が完了判定として定める command である。
