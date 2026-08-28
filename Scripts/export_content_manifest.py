#!/usr/bin/env python3
"""Export bundled Wuzzler puzzles into the remote static v1 manifest shape."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from validate_puzzles import (
    ROOT,
    load_json,
    require_date,
    require_future_coverage,
    validate_diagone,
    validate_rhymeagrams,
    validate_tumblepuns,
)


DIAGONE_PATH = ROOT / "Wuzzler/Games/Diagone/Puzzles/puzzles.json"
RHYMEAGRAMS_PATH = ROOT / "Wuzzler/Games/RhymeAGrams/Puzzles/rhymeagrams_puzzles.json"
TUMBLEPUNS_PATH = ROOT / "Wuzzler/Games/TumblePuns/Puzzles/tumblepuns_puzzles.json"


def validate(require_iso_date: str | None, minimum_future_days: int | None) -> None:
    errors: list[str] = []
    keys_by_game = {
        "Diagone": validate_diagone(DIAGONE_PATH, errors),
        "RhymeAGrams": validate_rhymeagrams(RHYMEAGRAMS_PATH, errors),
        "TumblePuns": validate_tumblepuns(TUMBLEPUNS_PATH, errors),
    }
    if require_iso_date:
        require_date(keys_by_game, require_iso_date, errors)
    if minimum_future_days is not None:
        require_future_coverage(keys_by_game, minimum_future_days, errors)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)


def build_manifest() -> dict:
    return {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "diagone": load_json(DIAGONE_PATH),
        "rhymeagrams": load_json(RHYMEAGRAMS_PATH),
        "tumblepuns": load_json(TUMBLEPUNS_PATH),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, help="Destination JSON path, e.g. build/content/v1/puzzles.json")
    parser.add_argument("--require-date", help="Require every game to contain this YYYY-MM-DD date before exporting.")
    parser.add_argument(
        "--minimum-future-days",
        type=int,
        help="Require continuous UTC puzzle coverage from today through this many days ahead.",
    )
    args = parser.parse_args()

    validate(args.require_date, args.minimum_future_days)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(build_manifest(), indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Exported {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
