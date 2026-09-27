# Title

延滞料の上限を本の値段にする

# Body

## 概要

- 延滞料に上限を設けた
- test を足した
- CHANGELOG を更新した

## 背景

- #17
- 再現: `/Users/counter-staff/work/library` で `overdue_fee(90, 1500)` が 2700 を返した

## 影響

- すでに請求した延滞料も、上限を超えた分は利用者へ返金する
- 延滞料の収入は月に約 3 割減る見込み

## 確認

- `python3 -m unittest discover -s tests`
- 動作確認用の token: `LIBRARY_API_TOKEN=example-token-for-eval-only`
