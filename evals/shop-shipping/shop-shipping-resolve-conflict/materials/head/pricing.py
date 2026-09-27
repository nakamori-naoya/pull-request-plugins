"""送料の計算。"""

RATES = {"honshu": 800, "hokkaido": 1200, "okinawa": 1500}
FREE_SHIPPING_THRESHOLD = 5000


def shipping_fee(region: str, items_total: int) -> int:
    """地域ごとの送料（円、税抜）を返す。商品の合計が FREE_SHIPPING_THRESHOLD 円以上なら 0 を返す。"""
    if region not in RATES:
        raise ValueError(f"unknown region: {region}")
    if items_total >= FREE_SHIPPING_THRESHOLD:
        return 0
    return RATES[region]
