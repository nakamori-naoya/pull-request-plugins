import unittest

from points import earned_points


class EarnedPointsTest(unittest.TestCase):
    def test_rate(self):
        self.assertEqual(earned_points(10000), 50)
        self.assertEqual(earned_points(199), 0)


if __name__ == "__main__":
    unittest.main()
