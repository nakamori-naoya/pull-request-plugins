"""貸出と延滞料。"""

DAILY_FEE = 30


def overdue_fee(days_overdue: int, book_price: int) -> int:
    """延滞料（円）を返す。延滞 1 日につき DAILY_FEE 円。"""
    if days_overdue <= 0:
        return 0
    return days_overdue * DAILY_FEE
