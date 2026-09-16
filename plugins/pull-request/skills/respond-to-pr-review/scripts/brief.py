#!/usr/bin/env python3
import argparse, json, os, tempfile

p = argparse.ArgumentParser()
p.add_argument("--assessment", required=True); p.add_argument("--out", required=True)
a = p.parse_args()
with open(a.assessment, encoding="utf-8") as h: data = json.load(h)
required_root = {"schema", "repository", "pull_request", "head_sha", "comments"}
required_comment = {"id", "decision", "intent", "reason", "proposed_change", "verification"}
# 入力の検査は「要るものが在るか」で行い、余分なキーがあっても落とさない。
# 完全一致で比べると、入力にキーが1つ増えただけでここが死ぬ。
# 逆に、契約が禁じる形（id重複、acceptなのにproposed_changeが空）は必ず拒む。
# **緩すぎても厳しすぎても、入力を作る側との判定が食い違って事故になる。**
if not isinstance(data, dict) or not required_root.issubset(data) \
        or data.get("schema") != 1 or not isinstance(data.get("comments"), list):
    raise SystemExit("assessment schemaが不正（必須: {}）".format(", ".join(sorted(required_root))))
seen_ids = set()
for item in data["comments"]:
    if not isinstance(item, dict) or not required_comment.issubset(item) or item.get("decision") not in {"accept", "reject", "defer"}:
        raise SystemExit("comment schemaが不正")
    if item["id"] in seen_ids:
        raise SystemExit("comment idが重複: {}".format(item["id"]))
    seen_ids.add(item["id"])
    if item["decision"] == "accept" and not str(item.get("proposed_change") or "").strip():
        raise SystemExit("acceptにはproposed_changeが必須: {}".format(item["id"]))
    if not isinstance(item.get("verification"), list) or not item["verification"]:
        raise SystemExit("verification schemaが不正")
accepted = [x for x in data.get("comments", []) if x.get("decision") == "accept"]
if not accepted:
    print(json.dumps({"status":"no_accepted_comments"})); raise SystemExit(3)
lines = ["# 採用されたPR review修正", "", "列挙したcommentだけを修正し、無関係な整理を行わない。", ""]
for i, x in enumerate(accepted, 1):
    lines += [f"## {i}. {x['id']}", "", f"- 対象: {x.get('path') or 'PR全体'}:{x.get('line') or '-'}", f"- 意図: {x['intent']}", f"- 採用理由: {x['reason']}", f"- 修正: {x['proposed_change']}", f"- 検証: {' / '.join(x['verification'])}", ""]
directory = os.path.dirname(os.path.abspath(a.out)); os.makedirs(directory, exist_ok=True)
fd, temporary = tempfile.mkstemp(prefix=".fix-brief-", dir=directory, text=True)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as h: h.write("\n".join(lines))
    os.replace(temporary, a.out)
except Exception:
    try: os.unlink(temporary)
    except OSError: pass
    raise
print(json.dumps({"status":"written","path":os.path.abspath(a.out),"accepted":len(accepted)}, ensure_ascii=False))
