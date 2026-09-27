"""買い物に付けるポイント。"""

EARN_RATE_PERCENT = 1.0
GOLD_EARN_RATE_PERCENT = 2.0


def earned_points(amount: int, gold: bool = False) -> int:
    """支払額（円）に付けるポイントを返す。ゴールド会員は付与率が高い。1 ポイント未満は切り捨てる。"""
    rate = GOLD_EARN_RATE_PERCENT if gold else EARN_RATE_PERCENT
    return int(amount * rate // 100)
