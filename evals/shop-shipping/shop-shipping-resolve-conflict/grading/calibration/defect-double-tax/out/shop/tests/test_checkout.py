import unittest

from checkout import order_total


class OrderTotalTest(unittest.TestCase):
    def test_adds_taxed_shipping(self):
        self.assertEqual(order_total(1000, "honshu"), 1880)

    def test_free_shipping(self):
        self.assertEqual(order_total(5000, "honshu"), 5000)


if __name__ == "__main__":
    unittest.main()
