#!/usr/bin/env python3
"""Validate Wuzzler Game Center metadata and achievement artwork."""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / "metadata.json"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

EXPECTED_ACHIEVEMENTS = {
    "wuzzler.achievement.first_solve": (10, "First Solve", "artwork/first-solve.png"),
    "wuzzler.achievement.first_daily_sweep": (
        25,
        "Daily Sweep",
        "artwork/first-daily-sweep.png",
    ),
    "wuzzler.achievement.streak_7": (50, "Seven-Day Streak", "artwork/streak-7.png"),
    "wuzzler.achievement.streak_14": (75, "Fourteen-Day Streak", "artwork/streak-14.png"),
    "wuzzler.achievement.streak_30": (100, "Thirty-Day Streak", "artwork/streak-30.png"),
    "wuzzler.achievement.diagone_first_solve": (
        10,
        "Diagone Debut",
        "artwork/first-diagone-solve.png",
    ),
    "wuzzler.achievement.rhymeagrams_first_solve": (
        10,
        "RhymeAGram Debut",
        "artwork/first-rhymeagram-solve.png",
    ),
    "wuzzler.achievement.tumblepuns_first_solve": (
        10,
        "TumblePun Debut",
        "artwork/first-tumblepun-solve.png",
    ),
}

EXPECTED_ACHIEVEMENT_COPY = {
    "wuzzler.achievement.first_solve": (
        "Solve any Wuzzler Daily puzzle.",
        "You solved your first Wuzzler Daily puzzle.",
    ),
    "wuzzler.achievement.first_daily_sweep": (
        "Complete all three daily puzzles in one UTC day.",
        "You completed a Daily Sweep.",
    ),
    "wuzzler.achievement.streak_7": (
        "Build a seven-day streak in any one Wuzzler game.",
        "You built a seven-day game streak.",
    ),
    "wuzzler.achievement.streak_14": (
        "Build a fourteen-day streak in any one Wuzzler game.",
        "You built a fourteen-day game streak.",
    ),
    "wuzzler.achievement.streak_30": (
        "Build a thirty-day streak in any one Wuzzler game.",
        "You built a thirty-day game streak.",
    ),
    "wuzzler.achievement.diagone_first_solve": (
        "Complete your first counted daily Diagone puzzle.",
        "You completed your first counted daily Diagone puzzle.",
    ),
    "wuzzler.achievement.rhymeagrams_first_solve": (
        "Complete your first counted daily RhymeAGram puzzle.",
        "You completed your first counted daily RhymeAGram puzzle.",
    ),
    "wuzzler.achievement.tumblepuns_first_solve": (
        "Complete your first counted daily TumblePun puzzle.",
        "You completed your first counted daily TumblePun puzzle.",
    ),
}

EXPECTED_LEADERBOARDS = {
    "wuzzler.diagone.daily": "Diagone Daily",
    "wuzzler.rhymeagrams.daily": "RhymeAGram Daily",
    "wuzzler.tumblepuns.daily": "TumblePun Daily",
    "wuzzler.sweep.daily": "Daily Sweep",
}


def load_manifest(errors: list[str]) -> dict:
    try:
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"Cannot read {MANIFEST}: {error}")
        return {}


def validate_metadata(payload: dict, errors: list[str]) -> list[Path]:
    if payload.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")
    if payload.get("locale") != "en-US":
        errors.append("locale must be en-US")

    achievements = payload.get("achievements")
    if not isinstance(achievements, list):
        errors.append("achievements must be an array")
        achievements = []

    achievement_ids = [item.get("id") for item in achievements if isinstance(item, dict)]
    if len(achievement_ids) != len(set(achievement_ids)):
        errors.append("achievement IDs must be unique")
    if set(achievement_ids) != set(EXPECTED_ACHIEVEMENTS):
        errors.append("achievement IDs do not match the eight identifiers compiled into Wuzzler")

    artwork_paths: list[Path] = []
    for achievement in achievements:
        if not isinstance(achievement, dict):
            errors.append("each achievement must be an object")
            continue
        identifier = achievement.get("id")
        expected = EXPECTED_ACHIEVEMENTS.get(identifier)
        if expected is not None:
            expected_points, expected_name, expected_artwork = expected
            if achievement.get("points") != expected_points:
                errors.append(f"{identifier}: points must be {expected_points}")
            for field in ("referenceName", "displayName"):
                if achievement.get(field) != expected_name:
                    errors.append(f"{identifier}: {field} must be {expected_name!r}")
            if achievement.get("artwork") != expected_artwork:
                errors.append(f"{identifier}: artwork must be {expected_artwork!r}")
        expected_copy = EXPECTED_ACHIEVEMENT_COPY.get(identifier)
        if expected_copy is not None:
            expected_pre_earned, expected_earned = expected_copy
            for field in ("requirement", "preEarnedDescription"):
                if achievement.get(field) != expected_pre_earned:
                    errors.append(f"{identifier}: {field} must be {expected_pre_earned!r}")
            if achievement.get("earnedDescription") != expected_earned:
                errors.append(
                    f"{identifier}: earnedDescription must be {expected_earned!r}"
                )
        if achievement.get("hidden") is not False:
            errors.append(f"{identifier}: hidden must be false")
        if achievement.get("repeatable") is not False:
            errors.append(f"{identifier}: repeatable must be false")
        for field in (
            "referenceName",
            "displayName",
            "requirement",
            "preEarnedDescription",
            "earnedDescription",
        ):
            if not isinstance(achievement.get(field), str) or not achievement[field].strip():
                errors.append(f"{identifier}: {field} must be non-empty text")
        artwork = achievement.get("artwork")
        if not isinstance(artwork, str) or not artwork.startswith("artwork/"):
            errors.append(f"{identifier}: artwork must name a file under artwork/")
        else:
            artwork_paths.append(ROOT / artwork)

    if sum(item.get("points", 0) for item in achievements if isinstance(item, dict)) > 1000:
        errors.append("total achievement points must not exceed 1000")
    if any(item.get("points", 0) > 100 for item in achievements if isinstance(item, dict)):
        errors.append("an achievement point value must not exceed 100")

    leaderboards = payload.get("leaderboards")
    if not isinstance(leaderboards, list):
        errors.append("leaderboards must be an array")
        leaderboards = []
    leaderboard_ids = [item.get("id") for item in leaderboards if isinstance(item, dict)]
    if len(leaderboard_ids) != len(set(leaderboard_ids)):
        errors.append("leaderboard IDs must be unique")
    if set(leaderboard_ids) != set(EXPECTED_LEADERBOARDS):
        errors.append("leaderboard IDs do not match the four identifiers compiled into Wuzzler")

    required_settings = {
        "type": "recurring",
        "recurrenceTimeZone": "UTC",
        "recurrenceStartPolicy": "next-utc-midnight-before-testing",
        "durationSeconds": 86400,
        "restartIntervalSeconds": 86400,
        "sortOrder": "low-to-high",
        "submissionPolicy": "best-score",
        "scoreUnit": "centiseconds",
        "scoreFormat": "elapsed-time-hundredths",
        "artwork": None,
    }
    for leaderboard in leaderboards:
        if not isinstance(leaderboard, dict):
            errors.append("each leaderboard must be an object")
            continue
        identifier = leaderboard.get("id")
        expected_name = EXPECTED_LEADERBOARDS.get(identifier)
        if expected_name is not None:
            for field in ("referenceName", "displayName"):
                if leaderboard.get(field) != expected_name:
                    errors.append(f"{identifier}: {field} must be {expected_name!r}")
        for field, expected in required_settings.items():
            if leaderboard.get(field) != expected:
                errors.append(f"{identifier}: {field} must be {expected!r}")

    if len(artwork_paths) != len(set(artwork_paths)):
        errors.append("each achievement must use a distinct artwork filename")
    return artwork_paths


def validate_png(path: Path, errors: list[str]) -> None:
    try:
        with path.open("rb") as image:
            if image.read(8) != PNG_SIGNATURE:
                errors.append(f"{path}: not a PNG file")
                return
            length_bytes = image.read(4)
            chunk_type = image.read(4)
            if len(length_bytes) != 4 or chunk_type != b"IHDR":
                errors.append(f"{path}: missing PNG IHDR")
                return
            length = struct.unpack(">I", length_bytes)[0]
            header = image.read(length)
            if length != 13 or len(header) != 13:
                errors.append(f"{path}: malformed PNG IHDR")
                return
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", header
            )
    except OSError as error:
        errors.append(f"{path}: {error.strerror or error}")
        return

    if (width, height) != (1024, 1024):
        errors.append(f"{path}: dimensions are {width}x{height}, expected 1024x1024")
    if bit_depth != 8 or color_type != 2:
        errors.append(f"{path}: must be 8-bit opaque RGB PNG (color type 2)")
    if compression != 0 or filtering != 0 or interlace not in (0, 1):
        errors.append(f"{path}: unsupported PNG encoding")


def main() -> int:
    errors: list[str] = []
    payload = load_manifest(errors)
    artwork_paths = validate_metadata(payload, errors) if payload else []
    for artwork_path in artwork_paths:
        validate_png(artwork_path, errors)

    if errors:
        print("Game Center validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        f"Validated {len(payload['achievements'])} achievements, "
        f"{len(payload['leaderboards'])} leaderboards, and {len(artwork_paths)} artwork files."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
