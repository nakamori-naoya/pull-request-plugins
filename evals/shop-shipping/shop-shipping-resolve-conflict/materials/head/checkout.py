"""注文の支払額の計算。"""

from pricing import shipping_fee

TAX_RATE_PERCENT = 10


def order_total(items_total: int, region: str) -> int:
    """商品の合計（円、税込）に、送料を税込にして足した支払額を返す。"""
    shipping = shipping_fee(region, items_total)
    return items_total + shipping * (100 + TAX_RATE_PERCENT) // 100
