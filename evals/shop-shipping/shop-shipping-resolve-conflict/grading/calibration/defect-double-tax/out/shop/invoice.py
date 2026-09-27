"""請求書の明細。"""

from pricing import shipping_fee


def invoice_lines(items_total: int, region: str) -> list[tuple[str, int]]:
    """請求書に載せる明細を返す。金額はすべて税込で、画面の支払額と一致させる。"""
    return [("商品", items_total), ("送料", shipping_fee(region))]
