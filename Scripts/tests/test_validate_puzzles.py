import sys
import unittest
from datetime import date, timedelta
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))

from validate_puzzles import DATE_FORMAT, require_future_coverage  # noqa: E402


class FutureCoverageTests(unittest.TestCase):
    def setUp(self):
        self.today = date(2026, 8, 28)

    def complete_keys(self, days):
        return {
            (self.today + timedelta(days=offset)).strftime(DATE_FORMAT)
            for offset in range(days + 1)
        }

    def test_accepts_today_through_minimum_future_day_inclusively(self):
        errors = []
        require_future_coverage(
            {"Diagone": self.complete_keys(30)},
            30,
            errors,
            today=self.today,
        )
        self.assertEqual(errors, [])

    def test_reports_each_game_missing_a_date(self):
        keys = self.complete_keys(30)
        missing = (self.today + timedelta(days=14)).strftime(DATE_FORMAT)
        keys.remove(missing)
        errors = []
        require_future_coverage(
            {"Diagone": keys, "TumblePuns": self.complete_keys(30)},
            30,
            errors,
            today=self.today,
        )
        self.assertEqual(errors, [f"Diagone: missing required puzzle date {missing}"])

    def test_rejects_negative_horizon(self):
        errors = []
        require_future_coverage({}, -1, errors, today=self.today)
        self.assertEqual(errors, ["--minimum-future-days must be zero or greater"])


if __name__ == "__main__":
    unittest.main()
