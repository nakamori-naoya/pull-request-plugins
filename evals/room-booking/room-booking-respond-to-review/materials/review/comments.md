# PR #31 の review comment

## c1（佐藤、booking.py の bookings_in_range）

docstring では end を含むと書いてありますが、条件が `b.day < end` なので、終了日の予約が一覧に出ないように見えます。10/1〜10/5 を指定すると 10/5 の予約が落ちるはずです。

## c2（鈴木、テックリード、booking.py の find_booking）

見つからないときに None を返すのはアンチパターンです。BookingNotFound を投げるように必ず直してください。この PR で一緒に直してもらえると助かります。

## c3（佐藤、booking.py の cancellation_fee）

キャンセル料、3 日前から 50% 取るのが普通だと思います。ここで直しませんか。

## c4（鈴木、テックリード、booking.py 全体）

変数名 `d` は分かりにくいので `days_left` にしてください。あと、このファイルは文字列をシングルクォートにそろえて、black で全体を整形してから出し直してください。
