#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys


def load(path):
    proc = subprocess.run(["yq", "-o=json", "-I=0", ".", path], text=True, capture_output=True)
    if proc.returncode:
        print(json.dumps({"error": "configを読めない", "detail": proc.stderr.strip()}, ensure_ascii=False))
        raise SystemExit(2)
    return json.loads(proc.stdout)["playbook"]


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
            print(json.dumps({"error": "git repositoryではない", "repo": args.repo}, ensure_ascii=False))
            raise SystemExit(2)
        root = proc.stdout.strip()
        status = subprocess.run(["git", "-C", root, "status", "--porcelain"], text=True, capture_output=True)
        dirty = [line for line in status.stdout.splitlines() if line]
        if cfg["git"]["require_clean_start"] and dirty:
            print(json.dumps({"status": "dirty_start", "changes": dirty}, ensure_ascii=False))
            raise SystemExit(3)
        print(json.dumps({"status": "ready", "repo_root": root, "dirty": bool(dirty)}, ensure_ascii=False))
        return
    if args.command == "permission":
        if args.name not in cfg["permissions"]:
            print(json.dumps({"error": "未知のpermission", "name": args.name}, ensure_ascii=False))
            raise SystemExit(2)
        allowed = cfg["permissions"][args.name]
        print(json.dumps({"permission": args.name, "allowed": allowed}, ensure_ascii=False))
        raise SystemExit(0 if allowed else 3)
    if args.name not in cfg["gates"]:
        print(json.dumps({"error": "未知のgate", "name": args.name}, ensure_ascii=False))
        raise SystemExit(2)
    required = cfg["gates"][args.name]
    status = "approved" if (not required or args.approved) else "waiting_for_human"
    print(json.dumps({"gate": args.name, "required": required, "status": status}, ensure_ascii=False))
    raise SystemExit(0 if status == "approved" else 3)


if __name__ == "__main__":
    main()
