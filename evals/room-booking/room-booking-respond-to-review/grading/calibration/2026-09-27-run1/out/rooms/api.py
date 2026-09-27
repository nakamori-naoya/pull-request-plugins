"""画面から呼ばれる入口。"""

from booking import Booking, find_booking


def booking_detail(bookings: list[Booking], booking_id: str) -> tuple[int, dict]:
    """予約の詳細を返す。無ければ 404。"""
    b = find_booking(bookings, booking_id)
    if b is None:
        return 404, {"error": "予約が見つからない"}
    return 200, {"id": b.booking_id, "room": b.room, "day": b.day.isoformat()}
