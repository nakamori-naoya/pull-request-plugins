import unittest

from loans import overdue_fee


class OverdueFeeTest(unittest.TestCase):
    def test_not_overdue(self):
        self.assertEqual(overdue_fee(0, 1500), 0)

    def test_daily(self):
        self.assertEqual(overdue_fee(3, 1500), 90)

    def test_capped_at_book_price(self):
        self.assertEqual(overdue_fee(90, 1500), 1500)
        self.assertEqual(overdue_fee(50, 1500), 1500)
        self.assertEqual(overdue_fee(49, 1500), 1470)


if __name__ == "__main__":
    unittest.main()
