---
name: create-pull-request
description: Gitの作業branchについてrepository規範、差分、commit、検証結果、既存PRを確認し、重複のないGitHub Pull Requestのtitleとbodyを組み立てて返す。「PRの本文を用意して」「pull requestを作成して」と言われたときに使う。実装変更や競合解消、push、PR作成そのものは行わない。
---

# create-pull-request

PR本文が書けただけでなく、目的、差分、検証、未確認事項を次のreviewへ渡せる状態を完了とする。

## 0. plugin rootを検証する

<!-- BEGIN shared:skill-entry/root-only -->
```bash
BUNDLE_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
if [ -d "${BUNDLE_ROOT}/skills/pull-request/pr-create" ]; then
  PLUGIN_ROOT="${BUNDLE_ROOT}/skills/pull-request/pr-create"
else
  PLUGIN_ROOT="${BUNDLE_ROOT}"
fi
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
```

**このコマンドは説明例ではない。必ず実行する。** 失敗したら先へ進まない。
<!-- END shared:skill-entry/root-only -->

## 1. 作業場所の値を入力として受け取る

呼び出し元から、base branch、remote、下書き設定、作業branchを**入力として**受け取る。どれかが欠けていたら停止する。**設定ファイルを探しに行かない。cacheや親directoryからpathを推測しない。別のbase/remote/下書き設定を自分で決めない。**

同じhead/baseへ開いているPR番号も渡される場合がある。`null`は「無い」ではなく「無いか、確認できなかった」なので、その場合は自分で重複を確認する。

baseからのcommitとdiff、実行済み検証、その変更が解決する目的を読む。競合解消結果を受け取った場合は、記録されたhead SHAと現在値、競合なし、検証成功を照合する。未検証を成功扱いしない。

## 2. PR内容を組み立てる

titleとbodyへ目的、主な変更、検証commandと結果、既知の制約、未確認事項を書く。競合を解消した場合は、競合の概要と採った方針、詳細資料の参照を含める。secret、local path、一時fileを本文へ入れない。

bodyは一時領域のファイルへ書き、その絶対pathを返す。

同じhead/baseのopen PRを確認する。存在すれば新規作成を要求せず、そのPRが現在headを指すことを確認して、そのPR numberとURLを返す。

## 3. 報告する

title、bodyを書いたファイルの絶対path、head/base、remote、下書き設定、検証結果、競合解消の有無、既存PRの有無、停止・未確認事項を返す。

**pushもPull Request作成もこのskillでは行わない。** それらは呼び出し元の段取りが公開Git操作の委譲先へ渡す。permission、human gate、`git` / `gh`の公開操作をここで再実装しない。
