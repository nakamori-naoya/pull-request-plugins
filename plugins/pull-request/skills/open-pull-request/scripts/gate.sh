#!/usr/bin/env bash
set -euo pipefail

report_ref=""
approved=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --report-ref)
      [ "$#" -ge 2 ] || { echo '{"status":"invalid","reason":"report_ref_missing"}'; exit 2; }
      report_ref="$2"
      shift 2
      ;;
    --approved)
      approved=true
      shift
      ;;
    *)
      echo '{"status":"invalid","reason":"unknown_argument"}'
      exit 2
      ;;
  esac
done

[ -n "$report_ref" ] || { echo '{"status":"invalid","reason":"report_ref_missing"}'; exit 2; }
if [ "$approved" != true ]; then
  jq -cn --arg report "$report_ref" '{status:"waiting_for_human",report:$report}'
  exit 3
fi
jq -cn --arg report "$report_ref" '{status:"approved",report:$report}'
