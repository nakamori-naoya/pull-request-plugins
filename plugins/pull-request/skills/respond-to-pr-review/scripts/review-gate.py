#!/usr/bin/env python3
"""respond-to-pr-review のrepository設定を読み、開始時worktree・review取込permission・gateを判定する。

  review-gate.py preflight  --config <repo>/.harness-plugins/respond-to-pr-review.config.yml --repo <repository>
  review-gate.py permission --config <同上> --name review_import|modify
  review-gate.py gate       --config <同上> --name after_assessment|before_modify|after_modify [--approved]

出力は標準出力のJSON 1文書。exit 0 = 通過、2 = 設定file不在・schema違反・引数不備、3 = dirty開始・permission拒否・承認待ち。
設定fileは1層で必須。同梱既定へのfallbackは無い。
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

REPORT_TIMINGS = ("after_assessment", "before_commit", "before_push", "after_push")
PERMISSIONS = ("review_import", "modify")
GATES = ("after_assessment", "before_modify", "after_modify")


def fail(payload, code=2):
    print(json.dumps(payload, ensure_ascii=False))
    raise SystemExit(code)


def validate_config(cfg, path):
    """key集合と型の完全一致。permission / gate の名前はこの入口が扱う review 判断だけに閉じる。"""
    if not isinstance(cfg, dict) or set(cfg) != {"version", "report", "permissions", "gates", "verification", "git"}:
        fail({"error": "設定のtop-level keyがschemaと一致しない（version / report / permissions / gates / verification / git）", "config": path})
    if type(cfg["version"]) is not int or cfg["version"] != 1:
        fail({"error": "versionは1だけを受け付ける", "config": path})
    report = cfg["report"]
    if not isinstance(report, dict) or set(report) != {"enabled", "timing"} or type(report["enabled"]) is not bool or report["timing"] not in REPORT_TIMINGS:
        fail({"error": "report は enabled(boolean) と timing({}) だけを持つ".format(" / ".join(REPORT_TIMINGS)), "config": path})
    permissions = cfg["permissions"]
    if not isinstance(permissions, dict) or set(permissions) != set(PERMISSIONS) or any(type(v) is not bool for v in permissions.values()):
        fail({"error": "permissions は review_import / modify のbooleanだけを持つ（公開Git操作の許可は agent-work-policy が判断する）", "config": path})
    gates = cfg["gates"]
    if not isinstance(gates, dict) or set(gates) != set(GATES) or any(type(v) is not bool for v in gates.values()):
        fail({"error": "gates は after_assessment / before_modify / after_modify のbooleanだけを持つ（commit / push のgateは agent-work-policy が判定する）", "config": path})
    verification = cfg["verification"]
    if (not isinstance(verification, dict) or set(verification) != {"commands"} or not isinstance(verification["commands"], list)
            or any(not isinstance(c, str) or not c for c in verification["commands"])):
        fail({"error": "verification.commands は空でない文字列の配列", "config": path})
    git = cfg["git"]
    if (not isinstance(git, dict) or set(git) != {"require_clean_start", "commit_message"} or type(git["require_clean_start"]) is not bool
            or not isinstance(git["commit_message"], str) or not git["commit_message"].strip()):
        fail({"error": "git は require_clean_start(boolean) と commit_message(空でない文字列) だけを持つ", "config": path})
    return cfg


def load(path):
    config = Path(path)
    if config.is_symlink() or not config.is_file():
        fail({"error": "設定fileが無い", "config": str(config), "reason": "policy_missing"})
    proc = subprocess.run(["yq", "-o=json", "-I=0", ".", str(config)], text=True, capture_output=True)
    if proc.returncode:
        fail({"error": "configを読めない", "detail": proc.stderr.strip()})
    return validate_config(json.loads(proc.stdout), str(config))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    preflight = sub.add_parser("preflight")
    preflight.add_argument("--config", required=True)
    preflight.add_argument("--repo", required=True)
    for command in ("permission", "gate"):
        item = sub.add_parser(command)
        item.add_argument("--config", required=True)
        item.add_argument("--name", required=True)
        if command == "gate":
            item.add_argument("--approved", action="store_true")
    args = parser.parse_args()
    cfg = load(args.config)
    if args.command == "preflight":
        proc = subprocess.run(["git", "-C", args.repo, "rev-parse", "--show-toplevel"], text=True, capture_output=True)
        if proc.returncode:
            fail({"error": "git repositoryではない", "repo": args.repo})
        root = proc.stdout.strip()
        expected = Path(root).resolve() / ".harness-plugins" / "respond-to-pr-review.config.yml"
        if Path(args.config).resolve() != expected:
            fail({"error": "設定と対象repositoryが一致しない", "config": str(Path(args.config).resolve()), "expected_config": str(expected)})
        status = subprocess.run(["git", "-C", root, "status", "--porcelain"], text=True, capture_output=True)
        dirty = [line for line in status.stdout.splitlines() if line]
        if cfg["git"]["require_clean_start"] and dirty:
            print(json.dumps({"status": "dirty_start", "changes": dirty}, ensure_ascii=False))
            raise SystemExit(3)
        print(json.dumps({"status": "ready", "repo_root": root, "dirty": bool(dirty)}, ensure_ascii=False))
        return
    if args.command == "permission":
        if args.name not in cfg["permissions"]:
            fail({"error": "未知のpermission", "name": args.name})
        allowed = cfg["permissions"][args.name]
        print(json.dumps({"permission": args.name, "allowed": allowed}, ensure_ascii=False))
        raise SystemExit(0 if allowed else 3)
    if args.name not in cfg["gates"]:
        fail({"error": "未知のgate", "name": args.name})
    required = cfg["gates"][args.name]
    status = "approved" if (not required or args.approved) else "waiting_for_human"
    print(json.dumps({"gate": args.name, "required": required, "status": status}, ensure_ascii=False))
    raise SystemExit(0 if status == "approved" else 3)


if __name__ == "__main__":
    main()
