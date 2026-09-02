#!/usr/bin/env bash
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
  ([.steps[] | select(.skill=="create-pull-request")]
    | length==1 and .[0].arguments==["--policy-root=${.deps[\"agent-work-policy\"].root}"])
' "$1" >/dev/null || { echo "[error] pull-request固有schemaが不正" >&2; exit 2; }
