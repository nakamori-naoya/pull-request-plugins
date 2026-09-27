"""会議室の予約。"""

from dataclasses import dataclass
from datetime import date


@dataclass(frozen=True)
class Booking:
    booking_id: str
    room: str
    day: date
    price: int


def is_available(bookings: list[Booking], room: str, day: date) -> bool:
    """その会議室のその日が空いているかを返す。"""
    return all(not (b.room == room and b.day == day) for b in bookings)


class BookingNotFound(Exception):
    pass


def find_booking(bookings: list[Booking], booking_id: str) -> Booking:
    """番号で予約を探す。見つからなければ BookingNotFound を投げる。"""
    for b in bookings:
        if b.booking_id == booking_id:
            return b
    raise BookingNotFound(booking_id)


def cancellation_fee(booking: Booking, today: date) -> int:
    """キャンセル料（円）を返す。利用日の前日と当日は利用料の全額、それより前は 0。"""
    d = (booking.day - today).days
    if d <= 1:
        return booking.price
    return 0


def bookings_in_range(bookings: list[Booking], room: str, start: date, end: date) -> list[Booking]:
    """その会議室の、start から end まで（end を含む）の予約を、利用日の順に返す。"""
    return sorted((b for b in bookings if b.room == room and start <= b.day <= end), key=lambda b: b.day)
