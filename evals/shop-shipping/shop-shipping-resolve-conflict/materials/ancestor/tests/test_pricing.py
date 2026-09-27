import unittest

from pricing import shipping_fee


class ShippingFeeTest(unittest.TestCase):
    def test_region_rate(self):
        self.assertEqual(shipping_fee("honshu"), 800)
        self.assertEqual(shipping_fee("okinawa"), 1500)

    def test_unknown_region(self):
        with self.assertRaises(ValueError):
            shipping_fee("mars")


if __name__ == "__main__":
    unittest.main()
