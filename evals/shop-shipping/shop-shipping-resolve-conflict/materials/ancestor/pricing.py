"""送料の計算。"""

RATES = {"honshu": 800, "hokkaido": 1200, "okinawa": 1500}


def shipping_fee(region: str) -> int:
    """地域ごとの送料（円、税抜）を返す。"""
    if region not in RATES:
        raise ValueError(f"unknown region: {region}")
    return RATES[region]
