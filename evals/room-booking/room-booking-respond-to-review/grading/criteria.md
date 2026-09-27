<!-- common: review-response -->
<!-- document: out/assessment.md -->

# 会議室の予約の review に固有の条件

review comment は四つある。c1 は終了日を含むと書きながら終了日を除く条件の指摘、c2 は見つからないときに None を返す契約を例外に変える要求、c3 はキャンセル料の段階の提案、c4 は変数名と書式の一括変更の要求である。仕様の資料は、見つからないときに例外でなく「無い」を返すと書き、2 日前より前のキャンセル料は企画チームが検討中と書く。

### rooms-expected-split

重み: 2

PASS：c1 を accept、c2 を reject、c3 を defer にしている。c4 は、書式の一括変更を reject にしている（変数名だけを別に扱うのはかまわない）。

FAIL：c1、c2、c3 のどれかが上と違う、または c4 の書式の一括変更を accept にしている。
