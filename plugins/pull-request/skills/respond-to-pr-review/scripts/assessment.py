#!/usr/bin/env python3
import argparse
import json
import sys


def fail(message):
    print(json.dumps({"error": message}, ensure_ascii=False))
    raise SystemExit(2)


def text(value, name, allow_empty=False):
    if not isinstance(value, str) or (not allow_empty and not value.strip()):
        fail("{} は{}文字列".format(name, "" if allow_empty else "空でない"))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["validate"])
    parser.add_argument("--file", required=True)
    args = parser.parse_args()
    try:
        with open(args.file, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        fail("assessmentを読めない: {}".format(exc))
    if not isinstance(data, dict) or data.get("schema") != 1:
        fail("schemaは1")
    text(data.get("repository"), "repository")
    if not isinstance(data.get("pull_request"), int) or data["pull_request"] <= 0:
        fail("pull_requestは正整数")
    text(data.get("head_sha"), "head_sha")
    comments = data.get("comments")
    if not isinstance(comments, list):
        fail("commentsは配列")
    seen = set()
    for index, item in enumerate(comments):
        if not isinstance(item, dict):
            fail("comments[{}]はobject".format(index))
        for key in ("id", "author", "body", "intent", "reason"):
            text(item.get(key), "comments[{}].{}".format(index, key))
        text(item.get("path"), "comments[{}].path".format(index), allow_empty=True)
        text(item.get("proposed_change"), "comments[{}].proposed_change".format(index), allow_empty=True)
        if item["id"] in seen:
            fail("comment idが重複: {}".format(item["id"]))
        seen.add(item["id"])
        if item.get("decision") not in ("accept", "reject", "defer"):
            fail("comments[{}].decisionが不正".format(index))
        if item["decision"] == "accept" and not item["proposed_change"].strip():
            fail("acceptにはproposed_changeが必須")
        checks = item.get("verification")
        if not isinstance(checks, list) or not all(isinstance(v, str) and v.strip() for v in checks):
            fail("comments[{}].verificationは非空文字列配列".format(index))
    counts = {key: sum(c["decision"] == key for c in comments) for key in ("accept", "reject", "defer")}
    print(json.dumps({"status": "valid", "comments": len(comments), "counts": counts}, ensure_ascii=False))


if __name__ == "__main__":
    main()
