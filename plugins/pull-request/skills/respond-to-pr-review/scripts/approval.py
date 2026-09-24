"""人の確認を、利用者の承認範囲に照らして通すかを決める。

承認範囲の形、組み立ててよい者、quote の入れ方は agent-work-policy の公開契約 §2.2 が持つ。
  approval = {"actions": [...], "pull_requests": [<PR番号>], "branches": [<作業branchまたは末尾 / のprefix>],
              "until": "<時差付きISO 8601>", "quote": ["<利用者の発言の原文>", ...]}
このpackageが持つのは、actions に並べてよい確認の名前だけである。名前は他のpackageの操作と重ならないよう
`pull-request/` で始め、単語をハイフンでつなぐ（pull-request/ready-for-review、pull-request/resolve-conflicts、
pull-request/after-assessment、pull-request/before-modify、pull-request/after-modify）。それ以外の名前は無視する。
"""
from __future__ import annotations

import json
from datetime import datetime

KEYS = {"actions", "pull_requests", "branches", "until", "quote"}


def parse_until(value: object) -> datetime | None:
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError:
        return None
    return parsed if parsed.tzinfo is not None else None


def parse(text: str) -> dict:
    """承認範囲のJSONを読み、形が合わなければ ValueError を送る。"""
    try:
        approval = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(f"approval is not JSON: {exc}") from exc
    if not isinstance(approval, dict) or not set(approval) <= KEYS or not {"actions", "until", "quote"} <= set(approval):
        raise ValueError("approval must have actions, pull_requests or branches, until, quote")
    actions = approval["actions"]
    if not isinstance(actions, list) or not actions or len(actions) != len(set(actions)) or any(not isinstance(item, str) or not item.strip() for item in actions):
        raise ValueError("approval actions must be unique non-empty names")
    if "pull_requests" not in approval and "branches" not in approval:
        raise ValueError("approval must enumerate pull_requests or branches")
    if any(type(item) is not int or item <= 0 for item in approval.get("pull_requests", [])) or not isinstance(approval.get("pull_requests", []), list):
        raise ValueError("approval pull_requests must be positive integers")
    if not isinstance(approval.get("branches", []), list) or any(not isinstance(item, str) or not item.strip() for item in approval.get("branches", [])):
        raise ValueError("approval branches must be non-empty strings")
    if parse_until(approval["until"]) is None:
        raise ValueError("approval until must be an ISO 8601 time with a UTC offset")
    quote = approval["quote"]
    if not isinstance(quote, list) or not quote or any(not isinstance(item, str) or not item.strip() for item in quote):
        raise ValueError("approval quote must list the user's own words verbatim")
    return approval


def branch_in_scope(branch: str | None, entries: list[str]) -> bool:
    """末尾が / の要素はprefixとして、それ以外は名前の完全一致で照合する。"""
    return branch is not None and any(branch.startswith(entry) if entry.endswith("/") else branch == entry for entry in entries)


def mismatch(approval: dict, action: str, pr: int | None, branch: str | None, now: datetime) -> list[str]:
    """今回の確認が承認範囲に入らない要素を返す。空なら範囲内。対象はPR番号か作業branchで、期限ちょうどは範囲外。"""
    outside = []
    if action not in approval["actions"]:
        outside.append("action")
    if pr is not None:
        if pr not in approval.get("pull_requests", []):
            outside.append("pull_request")
    elif not branch_in_scope(branch, approval.get("branches", [])):
        outside.append("branch")
    if not now < parse_until(approval["until"]):
        outside.append("until")
    return outside
