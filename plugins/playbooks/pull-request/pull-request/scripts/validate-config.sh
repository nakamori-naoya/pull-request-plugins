#!/usr/bin/env bash
# 公開Git操作は、外部pluginの公開playbookへ1呼び出し1actionで委譲する形だけを許す。
# 外部pluginのscript実行、外部rootからのpath組み立て、外部設定キーの複製は受け付けない。
set -euo pipefail
jq -e '
  (keys|sort)==["conflict_report","description","instructions","name","requires","steps","verification","version"] and
  ([.requires[].plugin]|sort)==["agent-work-policy","pr-conflict-inspect","pr-conflict-resolve","pr-create","write-doc"] and
  (.conflict_report|type=="object" and (keys|sort)==["timing"] and
    (.timing=="before_resolution" or .timing=="after_resolution")) and
  (.verification|type=="object" and (keys|sort)==["commands"] and
    (.commands|type=="array" and length>0 and all(.[]; type=="string" and length>0))) and
  ([.steps[] | select(.playbook=="write-doc")]|length==2) and
  ([.steps[] | select(.playbook=="write-doc") | .when]|sort)==[
    "conflict_state.has_conflicts && conflict_report.timing == after_resolution",
    "conflict_state.has_conflicts && conflict_report.timing == before_resolution"] and
  ([.steps[] | select(.script=="scripts/gate.sh" and
    .when=="conflict_state.has_conflicts && conflict_report.timing == before_resolution")]|length==1) and
  ([.steps[] | select(.skill=="inspect-pr-conflicts")]|length==1) and
  ([.steps[] | select(.skill=="resolve-pr-conflicts")]|length==1) and
  ([.steps[] | select(.skill=="create-pull-request")]|length==1) and
  ([.steps[] | select(.playbook=="agent-work-policy") | .input.action])==
    ["inspect","push","pull-request","ready-for-review"] and
  all(.steps[] | select(.playbook=="agent-work-policy");
    (.input|type=="object" and keys==["action"] and (.action|type=="string" and length>0)) and
    (has("script")|not) and (has("skill")|not)) and
  all(.steps[]; (has("plugin")|not) and (has("arguments")|not) and (has("actions")|not)) and
  all(.steps[] | select(.script!=null); .script|startswith("scripts/")) and
  ((.steps|tostring|contains(".deps"))|not)
' "$1" >/dev/null || { echo "[error] pull-request固有schemaが不正" >&2; exit 2; }
