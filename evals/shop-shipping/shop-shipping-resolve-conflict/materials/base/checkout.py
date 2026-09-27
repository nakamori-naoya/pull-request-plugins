"""注文の支払額の計算。"""

from pricing import shipping_fee


def order_total(items_total: int, region: str) -> int:
    """商品の合計（円、税込）に、税込の送料を足した支払額を返す。"""
    return items_total + shipping_fee(region)
