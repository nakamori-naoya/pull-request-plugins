# PR #31 review comment の評価

## c1: accept

終了日の予約が落ちるという指摘で、そのとおりなので `<=` に直した。

## c2: accept

テックリードの鈴木さんが「必ず直して」と書いているので、方針として従う。`find_booking` は BookingNotFound を投げるようにした。

## c3: reject

今のキャンセル料の実装は前日と当日が全額で、それで動いているので変えない。

## c4: accept

テックリードの指示なので、変数名の変更と black での整形は次の commit で行う。
