---
name: open-pull-request
description: Gitの作業branchとbase branchの競合を検出し、現行実装、関連する過去の修正・commit・GitHub PRから意図を理解して解消・検証した後、Pull Requestを作成する。「コンフリクトを解消してPRを作って」「PRを作成して」と言われたときに使う。競合資料は設定により解消前の提案または解消後の実績として提示する。
---

# open-pull-request

競合解消とPR作成を、設定された資料提示時点とrepositoryの公開規則を保って完了する。

## 1. 実行契約を受け取る

このSKILLを実行する同じagentが、同じdirectoryの`playbook.yml`と本文から参照する資料を全文読み、利用者の入力と明示された資料を保持した一つの文脈で最後まで判断する。YAMLの`steps`は工程順・`needs`・`provides`の正本であり、宣言順に辿る。`agent_work: invoking_agent`はこのagentが同じ文脈で担う調査・判断・変更・検証工程、`script:`は決定論的な安全gate、`playbook:`は外部公開Skillの直接呼び出しである。外部runtimeによる値注入や認知結果のfile relayを前提にしない。必要な入力や結果が無ければ推測せず停止する。

公開入力`document_destination`は資料化条件が成立したときに使う任意入力である。その時点では、新規作成なら`{output_directory: <既存の書き込み可能な絶対directory>, name: <.md名>}`、既存資料を更新するなら`{update_target: <既存Markdownの絶対path>}`のどちらか一方だけを持つobjectを必須とする。片側欠落、両方式混在、未知キー、未確定の保存先は補完せず、その資料化工程で停止する。競合がなく資料化工程が無効な場合は、未使用の保存先を質問・検査せずwrite-docを呼ばない。

`${.instructions.execution.directive}`に従い、`${.playbook.steps}`の責務を同じagentが上から実行する。`${.playbook.conflict_report.timing}`と`${.playbook.verification.commands}`は使用時に読む。

## 2. 入れ子の段取りを呼ぶ

`playbook:` の工程は、依存先が公開している入口と契約だけで実行する。依存先の中の工程名、skill、reference、設定キーは扱わない。

公開Skill `agent-work-policy:work-with-policy`には、`needs`で到達した実値から、`contract: agent-work-policy/agent-work-policy`、`version: 1`、対象repositoryの絶対pathである`repo`、1つの`action`を持つ完全な入力objectを実行時に組み立てて直接渡す。YAMLの`input`へactionだけの部分objectや、未解決の動的placeholderは置かない。**1回の呼び出しで頼む操作は1つだけである。** `inspect`と`push`にはaction固有キーを足さない。`pull-request`には`title`と実在する`body_file`の絶対path、`ready-for-review`には正の整数`pr`を足す。human gate後の再呼出しだけ`approved: true`を足し、そのactionが使わないキーは渡さない。設定ファイル、入力・出力YAML、依存先root、依存先の実行scriptは扱わない。

直接返されたobjectの`contract`、`version`、`action`が入力と一致し、`status`、`gate_state`、`operation_result`、`workspace`、`reason`が公開契約に合うことを確認する。`waiting_for_human`では`approval_target`を提示し、`failed`では`reason`を報告して停止する。`completed`のときだけaction固有の`operation_result`を後続へ使う。

資料化は`write-doc`契約v2の入力を公開Skill `write-doc:write-doc`へ直接渡す。同じagentが`needs`で受け取った競合評価、方針、解消結果、検証結果のうち選択した時点までに存在する値を読み、資料本文を`{kind: text, content: <本文>}`へ直接写す。値運搬用の素材fileは作らない。

`material`は上記text objectを1要素以上持つ配列とする。YAMLの`needs`で届いた公開`document_destination`を検査し、新規作成では`output_directory`と`name`、更新では`update_target`だけをそのまま渡す。保存先が無ければ推測せず停止する。結果は`status`と、成功時の絶対`path`または失敗時の`reason`として直接受け取り、`failed`や不正結果ではgate・解消・公開操作へ進まない。中間YAMLと出力YAMLは作らない。

各公開Skillにはそれぞれの公開契約入力を直接渡し、公開結果objectを直接受け取る。依存先の内部の値を読みに行かない。

公開Git操作の方針、permission、human gateは`agent-work-policy`の公開契約が所有し、この入口から差し替えない。

### 承認待ちの扱い

公開Git操作の工程が承認待ちを返したときは、返ってきた承認対象（何が、どこへ向かうか、詳細のpath）をそのまま利用者へ提示する。**実際に承認を得たときだけ**、同じ工程の入力に承認済みを明示して呼び直す。承認が得られなければ、その操作を実行済みとして扱わない。permissionそのものの拒否は承認質問へ変えない。

## 3. 競合を扱う

最初の工程は**何も変えない照会**である。返ってきた作業場所の値（base branch、remote、下書き設定、作業branch、worktree）と状態（working treeがcleanか、baseがあるか、その作業branchへ開いているPR番号）を、競合調査・解消・PR本文の組み立てへ明示的に渡す。**別のbase/remote/下書き設定を自分で決めない。** これらは公開出力からだけ受け取り、他所から推測しない。

開いているPR番号が `null` のときは「無い」と断定しない。**無いか、確認できなかったかのどちらか**である。PR本文の組み立てでは自分で重複を確認する。

この工程は既存の作業branchでもworking treeが汚れていても停止しない。新しい作業branchを始める判定は、この段取りの責務ではない。

競合調査を始める前に[競合から実装意図を復元する判断資料](../../../skills/pull-request/pr-conflict-inspect/references/investigation.md)を全文読む。解消が必要なら[意味を保つ競合解消の判断資料](../../../skills/pull-request/pr-conflict-resolve/references/resolution.md)も全文読む。同じagentが、両側の目的、取得不能と履歴なし、生成元と生成物、delete/modifyなどの境界を調査から解消まで保持する。

競合調査のSHAと証拠を保持する。競合が無ければ資料作成と解消を飛ばす。

`before_resolution`では、競合、両側の目的、推奨方針、検証案を資料化して利用者へ示す。明示承認を得るまでgateを通さず、解消を始めない。`after_resolution`では事前資料とgateを使わず、解消後に競合、採った方針、実際の修正、検証結果を資料化して示す。

解消工程には調査成果、base、remote、検証commandを渡す。現在SHAまたは競合集合が変わった場合は再調査なしに続けない。

## 4. PRを作成して報告する

競合なし、または解消と全検証が成功した場合だけPR本文の組み立てへ進む。組み立てたtitleとbody fileを、pushとPR作成の工程へ入力として渡す。

下書きPRをレビュー受付へ遷移するのは、利用者またはmanagerが内部レビュー完了を明示した後の最後の工程だけである。PR作成直後に無条件で遷移しない。

PR URLとnumber、head/base、競合の有無、資料の提示時点とpath、解消方針、検証結果、公開Git操作の結果と承認待ち・停止・未確認事項を報告する。
