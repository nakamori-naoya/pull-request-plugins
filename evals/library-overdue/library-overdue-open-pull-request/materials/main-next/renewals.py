"""貸出の延長。"""

MAX_RENEWALS = 2


def can_renew(renewed_count: int, reserved_by_others: bool) -> bool:
    """延長できるかを返す。ほかの人の予約があるときと、延長が上限に達したときは延長できない。"""
    return not reserved_by_others and renewed_count < MAX_RENEWALS
