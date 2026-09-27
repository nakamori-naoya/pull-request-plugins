import unittest

from points import earned_points


class EarnedPointsTest(unittest.TestCase):
    def test_rate(self):
        self.assertEqual(earned_points(10000), 100)
        self.assertEqual(earned_points(99), 0)

    def test_gold_rate(self):
        self.assertEqual(earned_points(10000, gold=True), 200)


if __name__ == "__main__":
    unittest.main()
