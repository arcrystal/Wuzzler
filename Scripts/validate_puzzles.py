#!/usr/bin/env python3
"""Validate Wuzzler puzzle JSON before shipping manual content."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATE_FORMAT = "%m/%d/%Y"
ISO_FORMAT = "%Y-%m-%d"
LETTERS_RE = re.compile(r"^[A-Z]+$")


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def parse_date(key: str, errors: list[str], source: str) -> None:
    try:
        datetime.strptime(key, DATE_FORMAT)
    except ValueError:
        errors.append(f"{source}: invalid date key {key!r}; expected MM/DD/YYYY")


def letters_only(value: str) -> str:
    return "".join(ch for ch in value.upper() if ch.isalpha())


def validate_diagone(path: Path, errors: list[str]) -> set[str]:
    data = load_json(path)
    keys = set(data)
    for key, words in data.items():
        parse_date(key, errors, "Diagone")
        if not isinstance(words, list) or len(words) != 6:
            errors.append(f"Diagone {key}: expected exactly six row words")
            continue
        for index, word in enumerate(words, start=1):
            if not isinstance(word, str) or len(word) != 6 or not LETTERS_RE.match(word.upper()):
                errors.append(f"Diagone {key}: row {index} must be a six-letter A-Z word")
    return keys


def validate_rhymeagrams(path: Path, errors: list[str]) -> set[str]:
    data = load_json(path)
    keys = set(data)
    expected_row_lengths = [1, 3, 5, 7]
    for key, puzzle in data.items():
        parse_date(key, errors, "RhymeAGrams")
        letters = puzzle.get("letters") if isinstance(puzzle, dict) else None
        solutions = puzzle.get("solutions") if isinstance(puzzle, dict) else None
        if not isinstance(letters, list) or [len(str(row)) for row in letters] != expected_row_lengths:
            errors.append(f"RhymeAGrams {key}: letters must have row lengths 1, 3, 5, 7")
            continue
        if not all(isinstance(row, str) and LETTERS_RE.match(row.upper()) for row in letters):
            errors.append(f"RhymeAGrams {key}: letter rows must contain only A-Z")
        if not isinstance(solutions, list) or len(solutions) != 4:
            errors.append(f"RhymeAGrams {key}: expected exactly four solutions")
            continue
        if not all(isinstance(word, str) and len(word) == 4 and LETTERS_RE.match(word.upper()) for word in solutions):
            errors.append(f"RhymeAGrams {key}: each solution must be a four-letter A-Z word")
            continue
        displayed = Counter("".join(row.upper() for row in letters))
        solved = Counter("".join(word.upper() for word in solutions))
        if displayed != solved:
            errors.append(f"RhymeAGrams {key}: displayed letters do not match solution letters exactly")
    return keys


def validate_tumblepuns(path: Path, errors: list[str]) -> set[str]:
    data = load_json(path)
    keys = set(data)
    for key, puzzle in data.items():
        parse_date(key, errors, "TumblePuns")
        if not isinstance(puzzle, dict):
            errors.append(f"TumblePuns {key}: puzzle must be an object")
            continue
        words = puzzle.get("words")
        if not isinstance(words, list) or len(words) != 4:
            errors.append(f"TumblePuns {key}: expected exactly four words")
            continue
        shaded_letters: list[str] = []
        for word_index, word in enumerate(words, start=1):
            solution = word.get("solution") if isinstance(word, dict) else None
            shaded = word.get("shadedIndices") if isinstance(word, dict) else None
            scrambled = word.get("scrambled") if isinstance(word, dict) else None
            if not isinstance(solution, str) or not LETTERS_RE.match(solution.upper()):
                errors.append(f"TumblePuns {key}: word {word_index} needs an A-Z solution")
                continue
            if scrambled is not None and Counter(scrambled.upper()) != Counter(solution.upper()):
                errors.append(f"TumblePuns {key}: word {word_index} scrambled letters do not match solution")
            if not isinstance(shaded, list) or not shaded:
                errors.append(f"TumblePuns {key}: word {word_index} needs shadedIndices")
                continue
            for shaded_index in shaded:
                if not isinstance(shaded_index, int) or not 1 <= shaded_index <= len(solution):
                    errors.append(f"TumblePuns {key}: word {word_index} has invalid shaded index {shaded_index!r}")
                    continue
                shaded_letters.append(solution.upper()[shaded_index - 1])

        answer = puzzle.get("answer")
        if not isinstance(answer, str) or not letters_only(answer):
            errors.append(f"TumblePuns {key}: answer must contain letters")
            continue
        if Counter(shaded_letters) != Counter(letters_only(answer)):
            errors.append(f"TumblePuns {key}: shaded letters do not match answer letters exactly")

        pattern = puzzle.get("answerPattern")
        if pattern is not None:
            expected_pattern = "".join("_" if ch.isalpha() else ch for ch in answer)
            if pattern != expected_pattern:
                errors.append(f"TumblePuns {key}: answerPattern should be {expected_pattern!r}")
    return keys


def require_date(keys_by_game: dict[str, set[str]], iso_date: str, errors: list[str]) -> None:
    try:
        date_key = datetime.strptime(iso_date, ISO_FORMAT).strftime(DATE_FORMAT)
    except ValueError:
        errors.append(f"--require-date expects YYYY-MM-DD, got {iso_date!r}")
        return
    for game, keys in keys_by_game.items():
        if date_key not in keys:
            errors.append(f"{game}: missing required puzzle date {date_key}")


def require_future_coverage(
    keys_by_game: dict[str, set[str]],
    minimum_future_days: int,
    errors: list[str],
    today=None,
) -> None:
    if minimum_future_days < 0:
        errors.append("--minimum-future-days must be zero or greater")
        return
    start = today or datetime.now(timezone.utc).date()
    for offset in range(minimum_future_days + 1):
        required = (start + timedelta(days=offset)).strftime(DATE_FORMAT)
        for game, keys in keys_by_game.items():
            if required not in keys:
                errors.append(f"{game}: missing required puzzle date {required}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-date", help="Also require every game to contain this YYYY-MM-DD date.")
    parser.add_argument(
        "--minimum-future-days",
        type=int,
        help="Require continuous UTC puzzle coverage from today through this many days ahead.",
    )
    args = parser.parse_args()

    errors: list[str] = []
    keys_by_game = {
        "Diagone": validate_diagone(ROOT / "Wuzzler/Games/Diagone/Puzzles/puzzles.json", errors),
        "RhymeAGrams": validate_rhymeagrams(ROOT / "Wuzzler/Games/RhymeAGrams/Puzzles/rhymeagrams_puzzles.json", errors),
        "TumblePuns": validate_tumblepuns(ROOT / "Wuzzler/Games/TumblePuns/Puzzles/tumblepuns_puzzles.json", errors),
    }

    if args.require_date:
        require_date(keys_by_game, args.require_date, errors)
    if args.minimum_future_days is not None:
        require_future_coverage(keys_by_game, args.minimum_future_days, errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    total = sum(len(keys) for keys in keys_by_game.values())
    print(f"Validated {total} puzzle entries across {len(keys_by_game)} games.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
