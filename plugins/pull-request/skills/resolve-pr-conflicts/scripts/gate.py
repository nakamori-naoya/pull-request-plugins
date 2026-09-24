#!/usr/bin/env python3
"""公開Git操作の外にある人間gateを、承認範囲に照らして通すか止める。

  python3 scripts/gate.py --action <gate名> --target <対象> [--approval '<承認範囲のJSON>']

出力は標準出力のJSON 1文書。
exit 0 = 承認範囲が今回の操作・対象・時刻を含む（{"status":"approved"}）。
exit 3 = 承認が無いか範囲の外（{"status":"waiting_for_human"}。範囲の外なら outside_approval に外れた要素）。
exit 2 = 引数または承認範囲の形が不正（{"status":"invalid"}）。
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone

import approval as approval_scope


def emit(payload: dict, code: int) -> None:
    print(json.dumps(payload, ensure_ascii=False))
    raise SystemExit(code)


def main() -> None:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--action")
    parser.add_argument("--target")
    parser.add_argument("--approval")
    try:
        args, extra = parser.parse_known_args()
    except SystemExit:
        emit({"status": "invalid", "reason": "arguments"}, 2)
    if extra or not args.action or not args.target:
        emit({"status": "invalid", "reason": "action_and_target_required"}, 2)
    result = {"action": args.action, "target": args.target}
    if args.approval is None:
        emit({"status": "waiting_for_human", **result}, 3)
    try:
        scope = approval_scope.parse(args.approval)
    except ValueError as exc:
        emit({"status": "invalid", "reason": "approval", "detail": str(exc)}, 2)
    outside = approval_scope.mismatch(scope, args.action, args.target, datetime.now(timezone.utc))
    if outside:
        emit({"status": "waiting_for_human", **result, "outside_approval": outside}, 3)
    emit({"status": "approved", **result}, 0)


if __name__ == "__main__":
    main()
