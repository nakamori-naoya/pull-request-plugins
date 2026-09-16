# 入力と変更契約

入力は`schema: 1`、repository、pull_request、head_sha、commentsを持つJSON。各commentはid、decision、intent、reason、proposed_change、verificationを持つ。decisionはaccept / reject / deferに限る。

acceptだけを変更対象とする。reject/defer、評価にない改善、format一括変更は対象外。成果は変更したrepository相対pathと、各pathに対応するcomment idを含める。
