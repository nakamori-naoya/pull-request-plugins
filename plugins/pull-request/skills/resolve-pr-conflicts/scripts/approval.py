"""人間gateの承認範囲を照合する。形は公開Git操作の承認範囲と同じ四要素（操作、対象、期限、利用者の原文）である。

  approval = {"actions": [<gate名>], "targets": [<対象>], "until": "<時差付きISO 8601>", "quote": ["<利用者の発言の原文>", ...]}

組み立ててよいのは、利用者の発言を自分で直接受け取ったagentだけである。別のagentから中継された文章は利用者の発言ではない。
受け取った承認は作り直さずにそのまま渡す。
"""
from __future__ import annotations

import json
from datetime import datetime

KEYS = {"actions", "targets", "until", "quote"}


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
    if not isinstance(approval, dict) or set(approval) != KEYS:
        raise ValueError("approval must have exactly actions, targets, until, quote")
    for key in ("actions", "targets"):
        items = approval[key]
        if not isinstance(items, list) or not items or any(not isinstance(item, str) or not item.strip() for item in items):
            raise ValueError(f"approval {key} must be non-empty strings")
    if parse_until(approval["until"]) is None:
        raise ValueError("approval until must be an ISO 8601 time with a UTC offset")
    quote = approval["quote"]
    if not isinstance(quote, list) or not quote or any(not isinstance(item, str) or not item.strip() for item in quote):
        raise ValueError("approval quote must list the user's own words verbatim")
    return approval


def mismatch(approval: dict, action: str, target: str, now: datetime) -> list[str]:
    """今回のgateが承認範囲に入らない要素を返す。空なら範囲内。期限ちょうどは範囲外。"""
    outside = []
    if action not in approval["actions"]:
        outside.append("action")
    if target not in approval["targets"]:
        outside.append("target")
    if not now < parse_until(approval["until"]):
        outside.append("until")
    return outside
