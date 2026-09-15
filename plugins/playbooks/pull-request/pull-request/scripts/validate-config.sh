#!/usr/bin/env bash
# 正本: agent-work-policy公開契約とこのplaybook.ymlのinputs/needs。
# 入力: 公開playbook設定1件。正規化: jqでobject・list・キー集合を比較する。
# 合格述語: 外部Git操作はplaybook工程であり、部分入力や動的placeholderをYAMLへ置かず、
# 同じagentがSKILLの指示どおりneedsから完全objectを組み立てられる。
# 診断: pull-request固有schemaが不正。正例: 現行4 action工程。
# 反例: action-only input、外部script、未宣言action。境界例: inspectもinputを静的宣言しない。
# 意味評価: 実行時objectの値とhuman gateの妥当性は公開SKILLを実読する。
set -euo pipefail
jq -e '
  (keys|sort)==["conflict_report","description","inputs","instructions","name","requires","steps","verification","version"] and
  .inputs==["repository_path","user_input","document_destination"] and
  ([.requires[].plugin]|sort)==["agent-work-policy","pr-conflict-inspect","pr-conflict-resolve","pr-create","write-doc"] and
  (.conflict_report|type=="object" and (keys|sort)==["timing"] and
    (.timing=="before_resolution" or .timing=="after_resolution")) and
  (.verification|type=="object" and (keys|sort)==["commands"] and
    (.commands|type=="array" and length>0 and all(.[]; type=="string" and length>0))) and
  ([.steps[] | select(.playbook=="write-doc")]|length==2) and
  all(.steps[] | select(.playbook=="write-doc"); .provides==["status","path","reason"]) and
  ([.steps[] | select(.playbook=="write-doc") | .when]|sort)==[
    "conflict_state.has_conflicts && conflict_report.timing == after_resolution",
    "conflict_state.has_conflicts && conflict_report.timing == before_resolution"] and
  (.steps[] | select(.id=="report-before-resolution") |
    .needs==["conflict_state","conflict_assessment","document_destination"]) and
  (.steps[] | select(.id=="report-after-resolution") |
    .needs==["conflict_state","conflict_assessment","conflict_resolution","conflict_verification","document_destination"]) and
  ([.steps[] | select(.script=="scripts/gate.sh" and
    .when=="conflict_state.has_conflicts && conflict_report.timing == before_resolution")]|length==1) and
  (.steps[] | select(.id=="approve-conflict-proposal") | .needs==["path"]) and
  ([.steps[] | select(has("agent_work")) | .id])==["inspect-conflicts","resolve-conflicts","prepare-pull-request"] and
  all(.steps[] | select(has("agent_work")); .agent_work=="invoking_agent" and (has("skill")|not)) and
  ([.steps[] | select(.playbook=="agent-work-policy") | .id])==
    ["workspace","push","create-pull-request","ready-for-review"] and
  all(.steps[] | select(.playbook=="agent-work-policy");
    (has("input")|not) and
    (has("script")|not) and (has("skill")|not)) and
  all(.steps[]; (has("plugin")|not) and (has("arguments")|not) and (has("actions")|not)) and
  all(.steps[] | select(.script!=null); .script|startswith("scripts/")) and
  .steps[0].needs==["repository_path"] and
  ((.steps|tostring|contains(".deps"))|not)
' "$1" >/dev/null || { echo "[error] pull-request固有schemaが不正" >&2; exit 2; }
