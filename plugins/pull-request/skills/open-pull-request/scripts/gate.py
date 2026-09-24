#!/usr/bin/env python3
"""公開Git操作の外にある人の確認を、承認範囲に照らして通すか止める。

  python3 scripts/gate.py --action <確認の名前> (--pr <PR番号> | --branch <作業branch>) [--approval '<承認範囲のJSON>']

出力は標準出力のJSON 1文書。
exit 0 = 承認範囲が今回の確認・対象・時刻を含む（{"status":"allowed"}）。
exit 3 = 承認が無いか範囲の外（{"status":"waiting_for_human"}。範囲の外なら outside_approval に外れた要素）。
exit 2 = 引数または承認範囲の形が不正（{"status":"invalid"}）。
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone

import approval as approval_scope


def emit(payload: dict, code: int) -> None:
    print(json.dumps(payload, ensure_ascii=False))
    raise SystemExit(code)


def main() -> None:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--action")
    parser.add_argument("--pr", type=int)
    parser.add_argument("--branch")
    parser.add_argument("--approval")
    try:
        args, extra = parser.parse_known_args()
    except SystemExit:
        emit({"status": "invalid", "reason": "arguments"}, 2)
    if extra or not args.action or (args.pr is None) == (args.branch is None) or (args.pr is not None and args.pr <= 0):
        emit({"status": "invalid", "reason": "action_and_one_target_required"}, 2)
    result = {"action": args.action, "pr": args.pr, "branch": args.branch}
    if args.approval is None:
        emit({"status": "waiting_for_human", **result}, 3)
    try:
        scope = approval_scope.parse(args.approval)
    except ValueError as exc:
        emit({"status": "invalid", "reason": "approval", "detail": str(exc)}, 2)
    outside = approval_scope.mismatch(scope, args.action, args.pr, args.branch, datetime.now(timezone.utc))
    if outside:
        emit({"status": "waiting_for_human", **result, "outside_approval": outside}, 3)
    emit({"status": "allowed", **result}, 0)


if __name__ == "__main__":
    main()
