#!/usr/bin/env bash
# 手元だけの git repository を作り、main と feature/free-shipping が競合する状態にする。
# remote は作業場所の中の bare repository だけにし、GitHub の remote を持たせない。
set -euo pipefail
CASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M="$CASE_DIR/materials"
export GIT_AUTHOR_NAME=shop-dev GIT_AUTHOR_EMAIL=shop-dev@example.invalid
export GIT_COMMITTER_NAME=shop-dev GIT_COMMITTER_EMAIL=shop-dev@example.invalid
mkdir -p out remote
git init -q --bare remote/shop.git
git init -q -b main out/shop
cd out/shop
git config user.name shop-dev
git config user.email shop-dev@example.invalid
snap() { find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +; cp -R "$M/$1/." .; git add -A; }
snap ancestor
GIT_AUTHOR_DATE=2026-09-01T10:00:00+09:00 GIT_COMMITTER_DATE=2026-09-01T10:00:00+09:00 git commit -q -m "送料と支払額の計算を置く"
git branch feature/free-shipping
snap base
GIT_AUTHOR_DATE=2026-09-10T10:00:00+09:00 GIT_COMMITTER_DATE=2026-09-10T10:00:00+09:00 git commit -q -F - <<'MSG'
送料を税込で返す

送料の請求書と画面の支払額が、税抜と税込で食い違っていた（問い合わせ #212）。送料の税込への換算を shipping_fee に寄せ、呼び出し側では税を足さない。請求書の明細（invoice.py）も shipping_fee の値をそのまま使い、明細の合計が画面の支払額と一致することを test で守る。
MSG
git checkout -q feature/free-shipping
snap head
GIT_AUTHOR_DATE=2026-09-08T10:00:00+09:00 GIT_COMMITTER_DATE=2026-09-08T10:00:00+09:00 git commit -q -F - <<'MSG'
5000 円以上の注文を送料無料にする

販促の施策で、商品の合計（税込）が 5000 円以上の注文は送料を無料にする。判定は商品の合計で行い、送料を含めない。shipping_fee に商品の合計を渡すようにした。
MSG
git remote add origin "$(cd ../../remote/shop.git && pwd)"
git push -q origin main feature/free-shipping
