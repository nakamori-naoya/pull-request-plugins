import unittest
from datetime import date

from booking import Booking, cancellation_fee, find_booking, is_available

B1 = Booking("b1", "A", date(2026, 10, 5), 3000)


class BookingTest(unittest.TestCase):
    def test_available(self):
        self.assertFalse(is_available([B1], "A", date(2026, 10, 5)))
        self.assertTrue(is_available([B1], "A", date(2026, 10, 6)))

    def test_find_missing_returns_none(self):
        self.assertIsNone(find_booking([B1], "zz"))

    def test_cancellation_fee(self):
        self.assertEqual(cancellation_fee(B1, date(2026, 10, 4)), 3000)
        self.assertEqual(cancellation_fee(B1, date(2026, 10, 3)), 0)


if __name__ == "__main__":
    unittest.main()
