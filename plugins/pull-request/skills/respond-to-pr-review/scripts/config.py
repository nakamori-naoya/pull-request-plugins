#!/usr/bin/env python3
"""respond-to-pr-review のrepository設定を読む決定論的tool。

  config.py check --repo <repository_path>
  config.py read  --repo <repository_path>

設定fileのpathは引数で受けず、<repository のgit root>/.harness-plugins/respond-to-pr-review.config.yml に固定する（1層・fallback無し）。
stdinは使わない。出力は標準出力のJSON 1文書。
  check: schema検査だけ。exit 0、{"status": "ok", "config": <絶対path>}
  read : schema検査後、exit 0、{"config": <絶対path>, "values": {<設定fileのtop-level keyと値をそのまま>}}
  失敗 : exit 2、{"error": <診断>, "config": <絶対path または null>, "reason": "policy_missing" | "schema_violation" | "not_a_git_repository"}
schema: version: 1、report.{enabled, timing}、permissions.{review_import, modify}、gates.{after_assessment, before_modify, after_modify}、
verification.commands、git.{require_clean_start, commit_message}。keyの過不足、型違い、許容外の値、公開Git操作のpermission / gateの混入は schema_violation。
review-gate.py（preflight / permission / gate）も同じ load() で設定を読む。
"""
import argparse
import json
import subprocess
from pathlib import Path

ENTRY = "respond-to-pr-review"
TOP_LEVEL = {"version", "report", "permissions", "gates", "verification", "git"}
REPORT_TIMINGS = ("after_assessment", "before_commit", "before_push", "after_push")
PERMISSIONS = ("review_import", "modify")
GATES = ("after_assessment", "before_modify", "after_modify")


def fail(error, config, reason):
    print(json.dumps({"error": error, "config": config, "reason": reason}, ensure_ascii=False))
    raise SystemExit(2)


def validate(cfg, path):
    """key集合と型の完全一致。permission / gate の名前はこの入口が扱う review 判断だけに閉じる。"""
    if not isinstance(cfg, dict) or set(cfg) != TOP_LEVEL:
        fail("設定のtop-level keyがschemaと一致しない（version / report / permissions / gates / verification / git）", path, "schema_violation")
    if type(cfg["version"]) is not int or cfg["version"] != 1:
        fail("versionは1だけを受け付ける", path, "schema_violation")
    report = cfg["report"]
    if not isinstance(report, dict) or set(report) != {"enabled", "timing"} or type(report["enabled"]) is not bool or report["timing"] not in REPORT_TIMINGS:
        fail("report は enabled(boolean) と timing({}) だけを持つ".format(" / ".join(REPORT_TIMINGS)), path, "schema_violation")
    permissions = cfg["permissions"]
    if not isinstance(permissions, dict) or set(permissions) != set(PERMISSIONS) or any(type(v) is not bool for v in permissions.values()):
        fail("permissions は review_import / modify のbooleanだけを持つ（公開Git操作の許可は agent-work-policy が判断する）", path, "schema_violation")
    gates = cfg["gates"]
    if not isinstance(gates, dict) or set(gates) != set(GATES) or any(type(v) is not bool for v in gates.values()):
        fail("gates は after_assessment / before_modify / after_modify のbooleanだけを持つ（commit / push のgateは agent-work-policy が判定する）", path, "schema_violation")
    verification = cfg["verification"]
    if (not isinstance(verification, dict) or set(verification) != {"commands"} or not isinstance(verification["commands"], list)
            or any(not isinstance(c, str) or not c for c in verification["commands"])):
        fail("verification.commands は空でない文字列の配列", path, "schema_violation")
    git = cfg["git"]
    if (not isinstance(git, dict) or set(git) != {"require_clean_start", "commit_message"} or type(git["require_clean_start"]) is not bool
            or not isinstance(git["commit_message"], str) or not git["commit_message"].strip()):
        fail("git は require_clean_start(boolean) と commit_message(空でない文字列) だけを持つ", path, "schema_violation")
    return cfg


def git_root(repo):
    proc = subprocess.run(["git", "-C", repo, "rev-parse", "--show-toplevel"], text=True, capture_output=True)
    if proc.returncode:
        fail("git repositoryではない: {}".format(repo), None, "not_a_git_repository")
    return Path(proc.stdout.strip()).resolve()


def load(repo):
    """設定を読んで検査し、(値, 設定fileの絶対path, git root) を返す。失敗はexit 2。"""
    root = git_root(repo)
    config = root / ".harness-plugins" / "{}.config.yml".format(ENTRY)
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
    return validate(cfg, path), path, root


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["check", "read"])
    parser.add_argument("--repo", required=True)
    args = parser.parse_args()
    cfg, path, _ = load(args.repo)
    if args.command == "check":
        print(json.dumps({"status": "ok", "config": path}, ensure_ascii=False))
        return
    print(json.dumps({"config": path, "values": cfg}, ensure_ascii=False))


if __name__ == "__main__":
    main()
