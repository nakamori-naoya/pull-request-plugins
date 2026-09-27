import unittest

from loans import overdue_fee


class OverdueFeeTest(unittest.TestCase):
    def test_not_overdue(self):
        self.assertEqual(overdue_fee(0, 1500), 0)

    def test_daily(self):
        self.assertEqual(overdue_fee(3, 1500), 90)


if __name__ == "__main__":
    unittest.main()
