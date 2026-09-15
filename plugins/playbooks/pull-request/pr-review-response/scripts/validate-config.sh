#!/usr/bin/env bash
# 正本: agent-work-policy公開契約、このplaybook.ymlのpermissions/gates/needs。
# 入力: 公開playbook設定1件。正規化: jqでobject・list・キー集合を比較する。
# 合格述語: review取込permissionが取得前にあり、accept 1件以上でだけassessment gateへ進み、
# Git操作は部分入力や動的placeholderをYAMLへ置かない外部playbook工程である。
# 診断: pr-review-response固有schemaが不正。正例: 現行宣言。
# 反例: permission工程欠落、無条件gate、action-only input。境界例: accept 0件はgate前終了。
# 意味評価: comment採否と利用者の承認は同じagentが判断する。
set -euo pipefail
jq -e '
  (.contract|type=="object" and (keys|sort)==["assessment_comment","assessment_root","decision"] and
    all(.[]; type=="array" and length>0 and all(.[]; type=="string" and length>0) and (length==(unique|length)))) and
  .inputs==["repository_path","pull_request","user_input","document_destination"] and
  ([.requires[].plugin]|sort)==["agent-work-policy","pr-review-apply","pr-review-assess","pr-review-verify","write-doc"] and
  (.permissions|type=="object" and (keys|sort)==["modify","review_import"] and all(.[]; type=="boolean")) and
  (.gates|type=="object" and (keys|sort)==["after_assessment","after_modify","before_modify"] and all(.[]; type=="boolean")) and
  (.report|type=="object" and (keys|sort)==["enabled","timing"] and (.enabled|type=="boolean") and
    (.timing=="after_assessment" or .timing=="before_commit" or .timing=="before_push" or .timing=="after_push")) and
  ((.report.enabled and any(.requires[]; .plugin=="write-doc")) or (.report.enabled|not)) and
  (.verification|type=="object" and (.commands|type=="array" and length>0 and all(.[]; type=="string" and length>0))) and
  (.git|type=="object" and (keys|sort)==["commit_message","require_clean_start"] and
    (.require_clean_start|type=="boolean") and
    (.commit_message|type=="string" and length>0)) and
  ([.steps[] | select(.playbook=="write-doc")]|length==4) and
  all(.steps[] | select(.playbook=="write-doc"); .provides==["status","path","reason"]) and
  ([.steps[] | select(.playbook=="write-doc") | .when]|sort)==[
    "assessment.accepted_count > 0 && report.enabled && report.timing == after_assessment","report.enabled && report.timing == after_push",
    "report.enabled && report.timing == before_commit","report.enabled && report.timing == before_push"] and
  (.steps[] | select(.id=="report-after-assessment") |
    .needs==["assessment","assessment_approved","document_destination"]) and
  (.steps[] | select(.id=="report-before-commit") |
    .needs==["assessment","change_report","verification","document_destination"]) and
  (.steps[] | select(.id=="report-before-push") |
    .needs==["assessment","change_report","verification","commit","document_destination"]) and
  (.steps[] | select(.id=="report-after-push") |
    .needs==["assessment","change_report","verification","commit","pushed_branch","document_destination"]) and
  ([.steps[] | select(.id=="commit" or .id=="push")]
    | length==2 and all(.[]; .playbook=="agent-work-policy" and
        (has("input")|not) and
        (has("script")|not) and (has("skill")|not))) and
  ([.steps[].id])==["preflight","review-import-permission","assess","assessment-gate",
    "report-after-assessment","modify-gate","modify","modified-gate","verify",
    "report-before-commit","commit","report-before-push","push","report-after-push"] and
  (.steps[] | select(.id=="review-import-permission") |
    .script=="scripts/review-gate.py" and .needs==["baseline"] and .provides==["review_import_allowed"]) and
  (.steps[] | select(.id=="assess") | .needs==["baseline","review_import_allowed"]) and
  (.steps[] | select(.id=="assessment-gate") | .when=="assessment.accepted_count > 0") and
  all(.steps[]; (has("plugin")|not) and (has("arguments")|not) and (has("actions")|not)) and
  all(.steps[] | select(.script!=null); .script=="scripts/review-gate.py") and
  ([.steps[] | select(has("agent_work")) | .id])==["assess","modify","verify"] and
  all(.steps[] | select(has("agent_work")); .agent_work=="invoking_agent" and (has("skill")|not)) and
  ((.steps|tostring|contains(".deps"))|not) and
  .steps[0].needs==["repository_path","pull_request"] and
  all(.steps[] | (.conditional_needs // [])[]; type=="object" and
    (.when|type=="string" and
      (. == "assessment.accepted_count > 0 && report.enabled && report.timing == after_assessment" or
       startswith("report.enabled && report.timing == "))) and
    (.needs|type=="array" and length>0 and all(.[]; type=="string")))
' "$1" >/dev/null || { echo "[error] pr-review-response固有schemaが不正" >&2; exit 2; }
