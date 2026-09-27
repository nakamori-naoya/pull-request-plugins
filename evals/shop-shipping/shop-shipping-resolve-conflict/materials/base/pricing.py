"""送料の計算。"""

RATES = {"honshu": 800, "hokkaido": 1200, "okinawa": 1500}  # 税抜
TAX_RATE_PERCENT = 10


def shipping_fee(region: str) -> int:
    """地域ごとの送料（円、税込）を返す。端数は切り捨てる。"""
    if region not in RATES:
        raise ValueError(f"unknown region: {region}")
    return RATES[region] * (100 + TAX_RATE_PERCENT) // 100
