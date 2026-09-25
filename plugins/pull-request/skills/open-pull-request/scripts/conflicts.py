#!/usr/bin/env python3
"""作業branchとbase branchの競合の有無と競合fileを、sourceを変えずに検出する決定論的tool。

  python3 scripts/conflicts.py --repo <repository_path> --base <base branchのref> --head <作業branchのref>

判定の順序は一つに決まっている。
  1. index に未解消のentry（git ls-files -u）があれば、進行中のmergeの競合として、そのfileを返す（method: unmerged_index）。
  2. 無ければ git merge-tree --write-tree で base と head を非破壊にmergeした結果を見る（method: merge_tree）。
     merge-tree の終了code 1 が競合あり、0 が競合なしである。working tree、index、refは変えない。
出力は標準出力のJSON 1文書。
  exit 0 = 判定できた。{"has_conflicts", "files": [<repository相対path>], "method", "base", "head", "base_sha", "head_sha"}
  exit 2 = 判定できない。{"error", "reason": "arguments" | "not_a_git_repository" | "unknown_ref" | "merge_tree_failed"}
競合の意味（両側の目的、どう解くか）は判定しない。
"""
import argparse
import json
import subprocess


def fail(error, reason):
    print(json.dumps({"error": error, "reason": reason}, ensure_ascii=False))
    raise SystemExit(2)


class Parser(argparse.ArgumentParser):
    def error(self, message):
        fail(message, "arguments")


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], text=True, capture_output=True)


def commit_of(repo, ref):
    proc = git(repo, "rev-parse", "--verify", "--quiet", "{}^{{commit}}".format(ref))
    if proc.returncode:
        fail("commitへ解決できないref: {}".format(ref), "unknown_ref")
    return proc.stdout.strip()


def main():
    parser = Parser(add_help=False)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    args = parser.parse_args()
    if git(args.repo, "rev-parse", "--show-toplevel").returncode:
        fail("git repositoryではない: {}".format(args.repo), "not_a_git_repository")
    base_sha = commit_of(args.repo, args.base)
    head_sha = commit_of(args.repo, args.head)
    result = {"base": args.base, "head": args.head, "base_sha": base_sha, "head_sha": head_sha}
    unmerged = git(args.repo, "ls-files", "-u", "-z")
    if unmerged.returncode:
        fail(unmerged.stderr.strip(), "merge_tree_failed")
    files = sorted({entry.split("\t", 1)[1] for entry in unmerged.stdout.split("\0") if entry})
    if files:
        print(json.dumps({"has_conflicts": True, "files": files, "method": "unmerged_index", **result}, ensure_ascii=False))
        return 0
    merged = git(args.repo, "merge-tree", "--write-tree", "--name-only", "--no-messages", "-z", base_sha, head_sha)
    if merged.returncode not in (0, 1):
        fail(merged.stderr.strip(), "merge_tree_failed")
    conflicted = sorted({name for name in merged.stdout.split("\0")[1:] if name}) if merged.returncode == 1 else []
    print(json.dumps({"has_conflicts": merged.returncode == 1, "files": conflicted, "method": "merge_tree", **result}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
