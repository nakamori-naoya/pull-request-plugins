import unittest

from checkout import order_total
from invoice import invoice_lines


class InvoiceTest(unittest.TestCase):
    def test_lines_match_order_total(self):
        lines = invoice_lines(1000, "honshu")
        self.assertEqual(lines, [("商品", 1000), ("送料", 880)])
        self.assertEqual(sum(amount for _, amount in lines), order_total(1000, "honshu"))


if __name__ == "__main__":
    unittest.main()
