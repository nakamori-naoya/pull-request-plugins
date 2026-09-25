#!/usr/bin/env python3
"""設定fileの verification.commands を記載順に実行する決定論的tool。

  python3 scripts/verify.py --repo <repository_path>

commandは同じdirectoryの config.py の load() で、この入口の設定file（<git root>/.harness-plugins/<入口>.config.yml）から読む。
引数、stdin、PR本文、review、logからcommandを受け取らない。空配列なら何も実行せず passed を返す。
各commandは git root を作業directoryにして bash -c で実行し、標準出力と標準エラーはcommandごとのlog fileへ分ける。
出力は標準出力のJSON 1文書。
  exit 0 = 全件成功。{"status": "passed", "commands": <実行件数>, "results": [{"command", "exit_code", "log_path"}]}
  exit 3 = 1件失敗。残りは実行しない。{"status": "failed", "commands": <実行件数>, "results": [...]}
  exit 2 = 引数不備（{"error", "config": null, "reason": "arguments"}）、または config.py と同じ設定の失敗
          （{"error", "config", "reason": "policy_missing" | "schema_violation" | "not_a_git_repository"}）
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

import config


class Parser(argparse.ArgumentParser):
    def error(self, message):
        config.fail(message, None, "arguments")


def main():
    parser = Parser(add_help=False)
    parser.add_argument("--repo", required=True)
    args = parser.parse_args()
    loaded = config.load(args.repo)
    values, path = loaded[0], loaded[1]
    root = Path(path).parent.parent
    logs = Path(tempfile.mkdtemp(prefix="pr-verification-"))
    results = []
    for index, command in enumerate(values["verification"]["commands"]):
        log = logs / "{}.log".format(index + 1)
        with log.open("w") as stream:
            os.chmod(log, 0o600)
            completed = subprocess.run(["bash", "-c", command], cwd=root, stdout=stream, stderr=subprocess.STDOUT)
        results.append({"command": command, "exit_code": completed.returncode, "log_path": str(log)})
        if completed.returncode:
            print(json.dumps({"status": "failed", "commands": len(results), "results": results}, ensure_ascii=False))
            return 3
    print(json.dumps({"status": "passed", "commands": len(results), "results": results}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
