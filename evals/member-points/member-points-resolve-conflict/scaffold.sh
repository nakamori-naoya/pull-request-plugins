#!/usr/bin/env bash
# 手元だけの git repository を作り、main と feature/gold-rate が、両側の意図を同時に満たせない形で競合する状態にする。
# remote は作業場所の中の bare repository だけにし、GitHub の remote を持たせない。
set -euo pipefail
CASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M="$CASE_DIR/materials"
export GIT_AUTHOR_NAME=points-dev GIT_AUTHOR_EMAIL=points-dev@example.invalid
export GIT_COMMITTER_NAME=points-dev GIT_COMMITTER_EMAIL=points-dev@example.invalid
mkdir -p out remote
git init -q --bare remote/points.git
git init -q -b main out/points
cd out/points
git config user.name points-dev
git config user.email points-dev@example.invalid
snap() { find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +; cp -R "$M/$1/." .; git add -A; }
snap ancestor
GIT_AUTHOR_DATE=2026-09-01T10:00:00+09:00 GIT_COMMITTER_DATE=2026-09-01T10:00:00+09:00 git commit -q -m "ポイントの計算を置く"
git branch feature/gold-rate
snap base
GIT_AUTHOR_DATE=2026-09-10T10:00:00+09:00 GIT_COMMITTER_DATE=2026-09-10T10:00:00+09:00 git commit -q -F - <<'MSG'
ポイントの付与率を 0.5% に下げる

原価の見直しで、10 月 1 日から通常の付与率を 1% から 0.5% に下げる（経理部の決定、社内の記録 #88）。会員への告知は経理部と広報が別に出す。
MSG
git checkout -q feature/gold-rate
snap head
GIT_AUTHOR_DATE=2026-09-08T10:00:00+09:00 GIT_COMMITTER_DATE=2026-09-08T10:00:00+09:00 git commit -q -F - <<'MSG'
ゴールド会員のポイントを 2 倍にする

販促チームの施策で、ゴールド会員は通常の 2 倍のポイントを付ける。10 月 1 日に送る告知文（docs/campaign.md）では「いつもの 2 倍、お支払い額の 2%」と書いている。
MSG
git remote add origin "$(cd ../../remote/points.git && pwd)"
git push -q origin main feature/gold-rate
