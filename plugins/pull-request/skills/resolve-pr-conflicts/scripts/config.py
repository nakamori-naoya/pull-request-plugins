#!/usr/bin/env python3
"""resolve-pr-conflicts のrepository設定を読む決定論的tool。

  config.py check --repo <repository_path>
  config.py read  --repo <repository_path>

設定fileのpathは引数で受けず、<repository のgit root>/.harness-plugins/resolve-pr-conflicts.config.yml に固定する（1層・fallback無し）。
stdinは使わない。出力は標準出力のJSON 1文書。
  check: schema検査だけ。exit 0、{"status": "ok", "config": <絶対path>}
  read : schema検査後、exit 0、{"config": <絶対path>, "values": {<設定fileのtop-level keyと値をそのまま>}}
  失敗 : exit 2、{"error": <診断>, "config": <絶対path または null>, "reason": "policy_missing" | "schema_violation" | "not_a_git_repository"}
schema: version: 1、conflict_report.timing（before_resolution | after_resolution）、verification.commands（空でない文字列の配列）。keyの過不足、型違い、許容外の値は schema_violation。
"""
import argparse
import json
import subprocess
from pathlib import Path

ENTRY = "resolve-pr-conflicts"
TOP_LEVEL = {"version", "conflict_report", "verification"}
TIMINGS = ("before_resolution", "after_resolution")


def fail(error, config, reason):
    print(json.dumps({"error": error, "config": config, "reason": reason}, ensure_ascii=False))
    raise SystemExit(2)


def validate(cfg, path):
    if not isinstance(cfg, dict) or set(cfg) != TOP_LEVEL:
        fail("設定のtop-level keyがschemaと一致しない（version / conflict_report / verification）", path, "schema_violation")
    if type(cfg["version"]) is not int or cfg["version"] != 1:
        fail("versionは1だけを受け付ける", path, "schema_violation")
    report = cfg["conflict_report"]
    if not isinstance(report, dict) or set(report) != {"timing"} or report["timing"] not in TIMINGS:
        fail("conflict_report は timing（{}）だけを持つ".format(" / ".join(TIMINGS)), path, "schema_violation")
    verification = cfg["verification"]
    if (not isinstance(verification, dict) or set(verification) != {"commands"} or not isinstance(verification["commands"], list)
            or any(not isinstance(c, str) or not c for c in verification["commands"])):
        fail("verification.commands は空でない文字列の配列", path, "schema_violation")
    return cfg


def locate(repo):
    proc = subprocess.run(["git", "-C", repo, "rev-parse", "--show-toplevel"], text=True, capture_output=True)
    if proc.returncode:
        fail("git repositoryではない: {}".format(repo), None, "not_a_git_repository")
    return Path(proc.stdout.strip()).resolve() / ".harness-plugins" / "{}.config.yml".format(ENTRY)


def load(repo):
    config = locate(repo)
    path = str(config)
    if config.is_symlink() or not config.is_file():
        fail("設定fileが無い", path, "policy_missing")
    loaded = subprocess.run(["yq", "-o=json", "-I=0", ".", path], text=True, capture_output=True)
    if loaded.returncode:
        fail("設定fileをYAMLとして読めない: {}".format(loaded.stderr.strip()), path, "schema_violation")
    try:
        cfg = json.loads(loaded.stdout)
    except json.JSONDecodeError as exc:
        fail("設定fileのparser出力が不正: {}".format(exc), path, "schema_violation")
    return validate(cfg, path), path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["check", "read"])
    parser.add_argument("--repo", required=True)
    args = parser.parse_args()
    cfg, path = load(args.repo)
    if args.command == "check":
        print(json.dumps({"status": "ok", "config": path}, ensure_ascii=False))
        return
    print(json.dumps({"config": path, "values": cfg}, ensure_ascii=False))


if __name__ == "__main__":
    main()
