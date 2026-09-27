#!/usr/bin/env bash
# 手元だけの git repository に、review を受けた作業 branch を置き、PR の本文と review comment を手元のファイルで渡す。
# remote は作業場所の中の bare repository だけにし、GitHub の remote を持たせない。
set -euo pipefail
CASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M="$CASE_DIR/materials"
export GIT_AUTHOR_NAME=rooms-dev GIT_AUTHOR_EMAIL=rooms-dev@example.invalid
export GIT_COMMITTER_NAME=rooms-dev GIT_COMMITTER_EMAIL=rooms-dev@example.invalid
at() { export GIT_AUTHOR_DATE=$1 GIT_COMMITTER_DATE=$1; }
mkdir -p out remote review
cp "$M/review/pr.md" "$M/review/comments.md" review/
git init -q --bare remote/rooms.git
git init -q -b main out/rooms
cd out/rooms
git config user.name rooms-dev
git config user.email rooms-dev@example.invalid
cp -R "$M/start/." .
git add -A
at 2026-09-01T10:00:00+09:00; git commit -q -m "会議室の予約を置く"
git checkout -q -b feature/range-list
cp -R "$M/feature/." .
git add -A
at 2026-09-20T10:00:00+09:00; git commit -q -m "会議室ごとに期間の予約の一覧を返す" -m "画面の週の予約のために、開始日と終了日を含む期間の予約を利用日の順に返す関数を足す。"
git remote add origin "$(cd ../../remote/rooms.git && pwd)"
git push -q origin main feature/range-list
