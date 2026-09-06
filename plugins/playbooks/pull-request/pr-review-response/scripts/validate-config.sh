#!/usr/bin/env bash
# 公開Git操作は、外部pluginの公開playbookへ1呼び出し1actionで委譲する形だけを許す。
# 外部pluginのscript実行、外部rootからのpath組み立て、外部設定キーの複製は受け付けない。
set -euo pipefail
jq -e '
  (.contract|type=="object" and (keys|sort)==["assessment_comment","assessment_root","decision"] and
    all(.[]; type=="array" and length>0 and all(.[]; type=="string" and length>0) and (length==(unique|length)))) and
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
  ([.steps[] | select(.playbook=="write-doc") | .when]|sort)==[
    "report.enabled && report.timing == after_assessment","report.enabled && report.timing == after_push",
    "report.enabled && report.timing == before_commit","report.enabled && report.timing == before_push"] and
  ([.steps[] | select(.id=="commit" or .id=="push")]
    | length==2 and all(.[]; .playbook=="agent-work-policy" and
        (.input|type=="object" and keys==["action"]) and
        (has("script")|not) and (has("skill")|not))) and
  ([.steps[] | select(.playbook=="agent-work-policy") | .input.action])==["commit","push"] and
  all(.steps[]; (has("plugin")|not) and (has("arguments")|not) and (has("actions")|not)) and
  all(.steps[] | select(.script!=null); .script=="scripts/review-gate.py") and
  ((.steps|tostring|contains(".deps"))|not) and
  all(.steps[] | (.conditional_needs // [])[]; type=="object" and
    (.when|type=="string" and startswith("report.enabled && report.timing == ")) and
    (.needs|type=="array" and length>0 and all(.[]; type=="string")))
' "$1" >/dev/null || { echo "[error] pr-review-response固有schemaが不正" >&2; exit 2; }
