---
name: create-pull-request
description: Gitの作業branchについてrepository規範、差分、commit、検証結果、既存PRを確認し、必要なpushを行って重複のないGitHub Pull Requestを作成しURLを返す。「PRを作って」「pull requestを作成して」と言われたときに使う。実装変更や競合解消は行わない。
---

# create-pull-request

PR URLが得られただけでなく、目的、差分、検証、未確認事項を次のreviewへ渡せる状態を完了とする。

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

## 1. 公開条件をAgent Work Policyへ委譲する

呼び出し元から`--policy-root=<Agent Work Policyの解決済み依存root>`を受け取る。これが無い、directoryでない、または`prepare.sh`と`control.py`を持たなければ停止する。cacheや親directoryからpathを推測しない。

受け取った`POLICY_ROOT`だけを使い、`POLICY_CFG=$(bash "$POLICY_ROOT/scripts/prepare.sh" "$(pwd)") || exit 2`で対象repositoryの解決済み設定を得る。`${.workspace.base_branch}`、`${.git.remote}`、`${.pull_request.draft}`はこの設定だけから読む。`control.py`だけにpushとPR作成を委譲し、下流側でpermission・human gate・base・remote・draft・`git` / `gh`公開操作を再実装しない。

公開方針はrepository単位で一つである。Agent Work Policyの`prepare.sh`へ`--scope`は渡さず、scope設定で公開permissionやhuman gateを差し替えない。

baseからのcommitとdiff、実行済み検証、その変更が解決する目的を読む。競合解消結果を受け取った場合は、記録されたhead SHAと現在値、競合なし、検証成功を照合する。未検証を成功扱いしない。

## 2. PR内容を組み立てる

titleとbodyへ目的、主な変更、検証commandと結果、既知の制約、未確認事項を書く。競合を解消した場合は、競合の概要と採った方針、詳細資料の参照を含める。secret、local path、一時fileを本文へ入れない。

同じhead/baseのopen PRを確認する。存在すれば重複作成せず、そのPRが現在headを指すことを確認して返す。

## 3. pushして作成する

`control.py push`、`control.py pull-request`を順に呼ぶ。`waiting_for_human`のときだけ対象を提示し、承認後に`--approved`を渡す。作成後のPR状態は再取得して照合するが、作成・push・mergeを直接実行しない。

## 4. 報告する

PR numberとURL、head/base、push先、title、検証結果、競合解消の有無、draft状態、停止・未確認事項を返す。実行していないpushや検証を成功として報告しない。
