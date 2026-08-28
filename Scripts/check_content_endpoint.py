#!/usr/bin/env python3
"""Validate the published Wuzzler puzzle manifest and its release horizon."""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from validate_puzzles import (
    require_future_coverage,
    validate_diagone,
    validate_rhymeagrams,
    validate_tumblepuns,
)


DEFAULT_URL = "https://arcrystal.github.io/Wuzzler/content/v1/puzzles.json"
MAXIMUM_BYTES = 2 * 1024 * 1024


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--minimum-future-days", type=int, default=30)
    args = parser.parse_args()

    parsed_url = urllib.parse.urlparse(args.url)
    if parsed_url.scheme != "https" or not parsed_url.hostname:
        print("ERROR: content endpoint must be an absolute HTTPS URL", file=sys.stderr)
        return 1

    request = urllib.request.Request(args.url, headers={"Accept": "application/json", "User-Agent": "WuzzlerContentHealth/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            status = response.status
            final_url = response.geturl()
            content_type = response.headers.get_content_type()
            payload = response.read(MAXIMUM_BYTES + 1)
    except (urllib.error.URLError, TimeoutError) as error:
        print(f"ERROR: content endpoint unavailable: {error}", file=sys.stderr)
        return 1

    errors: list[str] = []
    if status != 200:
        errors.append(f"unexpected HTTP status {status}")
    if final_url != args.url:
        errors.append(f"unexpected final URL {final_url!r}")
    if content_type != "application/json":
        errors.append(f"unexpected content type {content_type!r}")
    if len(payload) > MAXIMUM_BYTES:
        errors.append(f"manifest exceeds {MAXIMUM_BYTES} bytes")

    try:
        manifest = json.loads(payload)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        errors.append(f"invalid JSON: {error}")
        manifest = {}

    if not isinstance(manifest, dict):
        errors.append("manifest root must be an object")
        manifest = {}
    if manifest.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")

    for key in ("diagone", "rhymeagrams", "tumblepuns"):
        if not isinstance(manifest.get(key), dict):
            errors.append(f"{key} must be an object")

    keys_by_game: dict[str, set[str]] = {}
    if not errors:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, key, validator in (
                ("Diagone", "diagone", validate_diagone),
                ("RhymeAGrams", "rhymeagrams", validate_rhymeagrams),
                ("TumblePuns", "tumblepuns", validate_tumblepuns),
            ):
                path = root / f"{key}.json"
                path.write_text(json.dumps(manifest.get(key)), encoding="utf-8")
                keys_by_game[name] = validator(path, errors)
        require_future_coverage(keys_by_game, args.minimum_future_days, errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"Validated {args.url} with {args.minimum_future_days} days of future coverage.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
