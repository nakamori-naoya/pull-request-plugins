---
name: respond-to-pr-review
description: 指定GitHub PRのreview commentを取得・評価し、人間gateで採否を確認して、採用分だけを修正・検証する。commit・pushは`agent-work-policy`の公開playbookへ委譲する。reviewへの返信やresolveはしない。
---

# respond-to-pr-review

評価内容はsourceから判断し、工程順、操作許可、人間介入点は設定から変えない。

## 1. 実行契約を受け取る

このSKILLを実行する同じagentが、同じdirectoryの`playbook.yml`と本文から参照する資料を全文読み、利用者の入力と明示された資料を保持した一つの文脈で最後まで判断する。YAMLの`steps`は工程順・`needs`・`provides`の正本であり、宣言順に辿る。`agent_work: invoking_agent`はこのagentが同じ文脈で担う調査・判断・変更・検証工程、`script:`は決定論的な安全gate、`playbook:`は外部公開Skillの直接呼び出しである。外部runtimeによる値注入や認知結果のfile relayを前提にしない。必要な入力や結果が無ければ推測せず停止する。

公開入力`document_destination`は資料化条件が成立したときに使う任意入力である。採用が1件以上あり、`report.enabled`と選択した`report.timing`が当該report工程に一致した時点だけ必須とする。新規作成は`{output_directory: <既存の書き込み可能な絶対directory>, name: <.md名>}`、更新は`{update_target: <既存Markdownの絶対path>}`のどちらか一方だけを持つobjectである。片側欠落、両方式混在、未知キー、未確定の保存先は補完せず、その資料化工程と後続操作へ進まない。report無効、timing不一致、または採用0件では未使用の保存先を質問・検査せずwrite-docを呼ばない。

`${.instructions.execution.directive}`に従い`${.playbook.steps}`の責務を同じagentが上から実行する。`${.playbook.permissions}`と`${.playbook.gates}`はreview取込・修正だけに使う。公開Git操作のpermission、human gate、検証、実行は`playbook:`工程として委譲し、この入口から差し替えない。

## 2. 評価する

[PR review対応の判断規律](references/review-judgment.md)を全文読む。同じdirectoryの公開`playbook.yml`を`--config`へ直接渡して`review-gate.py preflight`でrepositoryと開始時worktreeを検査する。review取込前にも同じ公開`playbook.yml`を渡して`review-gate.py permission review_import`を通す。その後`assess`工程として、同じagentがGitHub MCPでreview commentを取得し、判断規律の`assess`に従ってsource、diff、test、必要な履歴と照合し、構造化した評価成果を提示する。旧内部skillや解決済みwrapperは呼ばない。

acceptが0件なら変更・gate・公開操作へ進まず、reject/deferの根拠を報告して終了する。1件以上ならYAMLの`assessment-gate`分岐に従って`after_assessment` gateを通す。

## 3. 採用分だけ修正する

`modify` permissionと`before_modify` gateを通し、同じagentが判断規律の`modify`に従ってacceptされた指摘だけを実装する。

差分と変更fileを提示し、`after_modify` gateを通す。評価でacceptされていない変更が混ざったら先へ進まない。

## 4. 検証し、公開操作を委譲する

同じagentが判断規律の`verify`に従い、公開YAMLの`verification.commands`を宣言順に実行する。失敗したらcommitしない。旧内部skillへ検証を委譲しない。

設定された時点でreportが有効なら資料化の段取りを呼び、その成果物を後続工程へ渡す。同じagentが各report工程の`needs`に届いた評価、採否、変更、検証、commit、push結果のうち、その時点までに存在する値を読み、本文を`{kind: text, content: <本文>}`にした1要素以上の`material`へ直接写す。公開`document_destination`を検査し、新規なら`output_directory`と`name`、更新なら`update_target`だけを`write-doc:write-doc`へ渡す。結果の`status`が`completed`で絶対`path`を返した場合だけ後続へ使い、`failed`なら`reason`を報告して停止する。中間素材file、入力・出力YAML、`output_to`、write-doc用の設定解決は使わない。

commitとpushは、それぞれ**1呼び出し1操作**として公開Skill `agent-work-policy:work-with-policy`へ委譲する。`needs`で到達したrepository、変更path、messageから公開契約の完全な入力objectを実行時に組み立てて直接渡し、公開結果objectを直接受け取る。YAMLの`input`へactionだけの部分objectや動的placeholderを置かない。設定ファイル、入力・出力YAML、依存先root、依存先の実行scriptは扱わない。

出力が承認待ちを示した場合だけ、同じ出力に含まれる承認対象を提示し、実際に承認を得てから同じ操作を承認済みとして呼び直す。公開操作のための独自permission・gate・`git`・`gh`は追加しない。

review固有のcommandとgateの呼び方、委譲の手順は[実行契約](references/workflow.md)に従う。公開操作の入力・出力・保証は委譲先が公開する契約を正本とする。

## 5. 報告する

PR、comment別採否、変更file、検証結果、commit、push先を報告する。未承認・未実行を成功扱いせず、reviewへの返信・thread resolveはしない。
