#!/usr/bin/env python3
"""respond-to-pr-review の開始時worktree・review取込permission・gateを判定する。

  review-gate.py preflight  --repo <repository_path>
  review-gate.py permission --repo <repository_path> --name review_import|modify
  review-gate.py gate       --repo <repository_path> --name after_assessment|before_modify|after_modify [--approved]

設定は同じdirectoryの config.py の load() で読む（<git root>/.harness-plugins/respond-to-pr-review.config.yml に固定・1層・fallback無し）。
出力は標準出力のJSON 1文書。exit 0 = 通過、2 = 設定file不在・schema違反・git repositoryでない・引数不備、3 = dirty開始・permission拒否・承認待ち。
"""
import argparse
import json
import subprocess

from config import fail, load


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    preflight = sub.add_parser("preflight")
    preflight.add_argument("--repo", required=True)
    for command in ("permission", "gate"):
        item = sub.add_parser(command)
        item.add_argument("--repo", required=True)
        item.add_argument("--name", required=True)
        if command == "gate":
            item.add_argument("--approved", action="store_true")
    args = parser.parse_args()
    cfg, path, root = load(args.repo)
    if args.command == "preflight":
        status = subprocess.run(["git", "-C", str(root), "status", "--porcelain"], text=True, capture_output=True)
        dirty = [line for line in status.stdout.splitlines() if line]
        if cfg["git"]["require_clean_start"] and dirty:
            print(json.dumps({"status": "dirty_start", "changes": dirty}, ensure_ascii=False))
            raise SystemExit(3)
        print(json.dumps({"status": "ready", "repo_root": str(root), "config": path, "dirty": bool(dirty)}, ensure_ascii=False))
        return
    if args.command == "permission":
        if args.name not in cfg["permissions"]:
            fail("未知のpermission: {}".format(args.name), path, "schema_violation")
        allowed = cfg["permissions"][args.name]
        print(json.dumps({"permission": args.name, "allowed": allowed}, ensure_ascii=False))
        raise SystemExit(0 if allowed else 3)
    if args.name not in cfg["gates"]:
        fail("未知のgate: {}".format(args.name), path, "schema_violation")
    required = cfg["gates"][args.name]
    status = "approved" if (not required or args.approved) else "waiting_for_human"
    print(json.dumps({"gate": args.name, "required": required, "status": status}, ensure_ascii=False))
    raise SystemExit(0 if status == "approved" else 3)


if __name__ == "__main__":
    main()
