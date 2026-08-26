---
name: create-pull-request
description: Gitの作業branchについてrepository規範、差分、commit、検証結果、既存PRを確認し、必要なpushを行って重複のないGitHub Pull Requestを作成しURLを返す。「PRを作って」「pull requestを作成して」と言われたときに使う。実装変更や競合解消は行わない。
---

# create-pull-request

PR URLが得られただけでなく、目的、差分、検証、未確認事項を次のreviewへ渡せる状態を完了とする。

## 0. plugin rootを検証する

<!-- BEGIN shared:skill-entry/root-only -->
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
```

**このコマンドは説明例ではない。必ず実行する。** 失敗したら先へ進まない。
<!-- END shared:skill-entry/root-only -->

## 1. 公開条件を確認する

repositoryの正式な作業規範を読み、pushとPR作成のpermission・human gateを確認する。base、head、remoteを特定し、baseへの直接push、detached HEAD、unmerged entry、対象外の未commit変更があれば停止する。

baseからのcommitとdiff、実行済み検証、その変更が解決する目的を読む。競合解消結果を受け取った場合は、記録されたhead SHAと現在値、競合なし、検証成功を照合する。未検証を成功扱いしない。

## 2. PR内容を組み立てる

titleとbodyへ目的、主な変更、検証commandと結果、既知の制約、未確認事項を書く。競合を解消した場合は、競合の概要と採った方針、詳細資料の参照を含める。secret、local path、一時fileを本文へ入れない。

同じhead/baseのopen PRを確認する。存在すれば重複作成せず、そのPRが現在headを指すことを確認して返す。

## 3. pushして作成する

必要な場合だけ許可されたremoteへ現在branchをpushする。force pushは明示許可なしに行わない。gateがある操作は対象を提示し、承認後だけ実行する。

認証済みGitHub手段で指定baseへのPRを作る。作成後にnumber、URL、head、base、draft状態を再取得し、意図したPRと一致しなければ完了にしない。

## 4. 報告する

PR numberとURL、head/base、push先、title、検証結果、競合解消の有無、draft状態、停止・未確認事項を返す。実行していないpushや検証を成功として報告しない。
