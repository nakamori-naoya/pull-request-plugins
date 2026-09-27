#!/usr/bin/env bash
# 手元だけの git repository を作り、main から分かれた feature/overdue-cap を置く。main は分かれた後に競合しない変更で進める。
# remote は作業場所の中の bare repository だけにし、GitHub の remote を持たせない。
set -euo pipefail
CASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M="$CASE_DIR/materials"
export GIT_AUTHOR_NAME=library-dev GIT_AUTHOR_EMAIL=library-dev@example.invalid
export GIT_COMMITTER_NAME=library-dev GIT_COMMITTER_EMAIL=library-dev@example.invalid
at() { export GIT_AUTHOR_DATE=$1 GIT_COMMITTER_DATE=$1; }
mkdir -p out remote
git init -q --bare remote/library.git
git init -q -b main out/library
cd out/library
git config user.name library-dev
git config user.email library-dev@example.invalid
cp -R "$M/start/." .
git add -A
at 2026-09-01T10:00:00+09:00; git commit -q -m "貸出と延滞料を置く"
git branch feature/overdue-cap
cp "$M/main-next/renewals.py" .
git add -A
at 2026-09-12T10:00:00+09:00; git commit -q -m "貸出の延長の可否を足す"
git checkout -q feature/overdue-cap
cp -R "$M/feature/." .
git add -A
at 2026-09-15T10:00:00+09:00; git commit -q -F - <<'MSG'
延滞料の上限を本の値段にする

#17 の苦情を受け、館の運営会議の方針に合わせて、延滞料をその本の値段で打ち止めにする。50 日で 1,500 円の本の値段に届く境目を test で守る。すでに請求した延滞料にはさかのぼって上限を当てない。請求済みの額は会計の記録と突き合わせる必要があり、#17 でも別に決めるとしているからである。
MSG
cp "$M/dot-env" .env
git remote add origin "$(cd ../../remote/library.git && pwd)"
git push -q origin main feature/overdue-cap
