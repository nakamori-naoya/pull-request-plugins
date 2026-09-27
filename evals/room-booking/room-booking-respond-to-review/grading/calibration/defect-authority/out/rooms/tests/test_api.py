import unittest
from datetime import date

from api import booking_detail
from booking import Booking


class ApiTest(unittest.TestCase):
    def test_missing_is_404(self):
        self.assertEqual(booking_detail([], "zz")[0], 404)

    def test_found(self):
        b = Booking("b1", "A", date(2026, 10, 5), 3000)
        self.assertEqual(booking_detail([b], "b1")[0], 200)


if __name__ == "__main__":
    unittest.main()
