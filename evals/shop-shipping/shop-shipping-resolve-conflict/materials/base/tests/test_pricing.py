import unittest

from pricing import shipping_fee


class ShippingFeeTest(unittest.TestCase):
    def test_region_rate_includes_tax(self):
        self.assertEqual(shipping_fee("honshu"), 880)
        self.assertEqual(shipping_fee("okinawa"), 1650)

    def test_unknown_region(self):
        with self.assertRaises(ValueError):
            shipping_fee("mars")


if __name__ == "__main__":
    unittest.main()
