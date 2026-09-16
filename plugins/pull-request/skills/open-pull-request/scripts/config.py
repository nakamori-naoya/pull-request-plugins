#!/usr/bin/env python3
"""open-pull-request のrepository設定を読み、schemaを検査して値を返す。

  config.py --repo <repository>

<repository のgit root>/.harness-plugins/open-pull-request.config.yml を読む（1層・必須・fallback無し）。
出力は標準出力のJSON 1文書 {"conflict_report": {"timing": ...}, "verification": {"commands": [...]}, "config": <絶対path>}。
exit 0 = 読めた、2 = 設定file不在・schema違反・git repositoryでない（診断は標準出力のJSON error）。
"""
import argparse
import json
import subprocess
from pathlib import Path

TIMINGS = ("before_resolution", "after_resolution")


def fail(payload):
    print(json.dumps(payload, ensure_ascii=False))
    raise SystemExit(2)


def validate_config(cfg, path):
    if not isinstance(cfg, dict) or set(cfg) != {"version", "conflict_report", "verification"}:
        fail({"error": "設定のtop-level keyがschemaと一致しない（version / conflict_report / verification）", "config": path})
    if type(cfg["version"]) is not int or cfg["version"] != 1:
        fail({"error": "versionは1だけを受け付ける", "config": path})
    report = cfg["conflict_report"]
    if not isinstance(report, dict) or set(report) != {"timing"} or report["timing"] not in TIMINGS:
        fail({"error": "conflict_report は timing（{}）だけを持つ".format(" / ".join(TIMINGS)), "config": path})
    verification = cfg["verification"]
    if (not isinstance(verification, dict) or set(verification) != {"commands"} or not isinstance(verification["commands"], list)
            or any(not isinstance(c, str) or not c for c in verification["commands"])):
        fail({"error": "verification.commands は空でない文字列の配列", "config": path})
    return cfg


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    args = parser.parse_args()
    proc = subprocess.run(["git", "-C", args.repo, "rev-parse", "--show-toplevel"], text=True, capture_output=True)
    if proc.returncode:
        fail({"error": "git repositoryではない", "repo": args.repo})
    config = Path(proc.stdout.strip()).resolve() / ".harness-plugins" / "open-pull-request.config.yml"
    if config.is_symlink() or not config.is_file():
        fail({"error": "設定fileが無い", "config": str(config), "reason": "policy_missing"})
    loaded = subprocess.run(["yq", "-o=json", "-I=0", ".", str(config)], text=True, capture_output=True)
    if loaded.returncode:
        fail({"error": "configを読めない", "config": str(config), "detail": loaded.stderr.strip()})
    cfg = validate_config(json.loads(loaded.stdout), str(config))
    print(json.dumps({"conflict_report": cfg["conflict_report"], "verification": cfg["verification"], "config": str(config)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
