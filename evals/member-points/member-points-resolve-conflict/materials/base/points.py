"""買い物に付けるポイント。"""

EARN_RATE_PERCENT = 0.5


def earned_points(amount: int) -> int:
    """支払額（円）に付けるポイントを返す。1 ポイント未満は切り捨てる。"""
    return int(amount * EARN_RATE_PERCENT // 100)
