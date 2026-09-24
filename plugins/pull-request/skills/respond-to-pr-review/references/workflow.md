# 実行契約

このplaybookが自分で判断するのは、review取込と修正だけである。公開Git操作は`playbook:`工程として委譲し、その入口・入力・出力・保証以外には依存しない。

## preflight

`scripts/review-gate.py preflight` がrepositoryと開始時worktreeを検査した結果を受け取る。設定fileの `git.require_clean_start` がtrueなら、開始時にtracked/untracked変更が1件でもあれば停止する。

## permission

review取込と修正のpermission工程が返す許可・禁止を使う。禁止を承認質問で上書きしない。

## gate

`after_assessment`、`before_modify`、`after_modify`のgate工程が承認必須を返した場合は人間へ確認し、明示承認後だけ同じgateへ承認済みの事実を返す。未承認なら後続へ進まない。

## 公開Git操作の委譲

`commit`と`push`は、公開Skill `agent-work-policy:agent-work-policy`へ**1呼び出し1操作**で委譲する。公開契約の入力objectを直接渡し、公開結果objectを直接受け取る。そのactionが使わないキーは渡さない。依存先root、内部工程、script、設定ファイル、入力・出力YAMLは扱わない。

入力objectは`contract: agent-work-policy/agent-work-policy`、`version: 1`、`action`、`repo`としてrepositoryの絶対path、およびそのactionに必要な値だけを持つ。commitではrepository相対pathの`paths`と`message`を渡す。pushにaction固有キーを足さない。利用者の承認があるときだけ、その発言から作った承認範囲`approval`（操作、対象、期限、発言の原文）を足す。公開方針はrepository単位で一つであり、呼び出し元から差し替えない。

直接結果の`contract`、`version`、`action`が入力と一致し、`status`、`gate_state`、`operation_result`、`workspace`、`reason`が公開schemaに合うことを確認する。`waiting_for_human`では`approval_target`を利用者へ提示し、`failed`では`reason`を報告して停止する。`completed`のときだけcommitまたはpushの`operation_result`を後続へ使う。

### 承認待ち

出力が承認待ちを示したときは、同じ出力に含まれる承認対象（何が、どこへ向かうか、詳細のpath）をそのまま利用者へ提示する。**実際に承認を得たときだけ**、同じ操作の入力に承認済みを明示して呼び直す。承認が得られなければ、その操作を実行済みとして扱わない。permissionそのものの拒否は承認質問へ変えない。

## report

設定fileの `report.enabled: false` なら資料工程をすべてskipする。trueなら `report.timing` に一致する1工程だけを実行する。資料成果物は直後のgateまたは後続工程の`conditional_needs`で拘束される。

資料化は`write-doc`契約v2として公開Skill `write-doc:write-doc`へ直接委譲する。同じagentが当該report工程の`needs`で受け取った評価、採否、変更、検証、commit、push結果のうち、その時点までに存在する実値から本文を作り、`[{kind: text, content: <本文>}]`として直接渡す。実際の資料化条件が成立した時点だけ公開`document_destination`を検査し、新規作成では`output_directory`と`name`、更新では`update_target`だけを渡す。report無効、timing不一致、採用0件では未使用の保存先を質問・検査しない。条件成立時に保存先が無い、片側が欠ける、または新規と更新が混在する場合は推測せず停止する。結果の`status`と、成功時の`path`または失敗時の`reason`を直接受け取り、中間素材file、中間YAML、`output_to`は使わない。

## 実行状態の後始末

この入口が作った一時物は同じagentが明示pathで管理し、依存先が内部で作った実行状態は各公開Skillが所有する。この入口は依存先の実行状態を作成・削除しない。
