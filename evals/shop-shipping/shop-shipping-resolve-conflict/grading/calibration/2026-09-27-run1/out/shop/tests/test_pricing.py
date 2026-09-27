import unittest

from pricing import shipping_fee


class ShippingFeeTest(unittest.TestCase):
    def test_region_rate_includes_tax(self):
        self.assertEqual(shipping_fee("honshu", 1000), 880)
        self.assertEqual(shipping_fee("okinawa", 4999), 1650)

    def test_free_from_threshold(self):
        self.assertEqual(shipping_fee("honshu", 5000), 0)
        self.assertEqual(shipping_fee("okinawa", 12000), 0)

    def test_unknown_region(self):
        with self.assertRaises(ValueError):
            shipping_fee("mars", 1000)


if __name__ == "__main__":
    unittest.main()
