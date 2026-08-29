# Game Center submission assets

`metadata.json` is the source of truth for the English (U.S.) Game Center records entered in App Store Connect. Achievement IDs and leaderboard IDs must match the identifiers compiled into Wuzzler exactly.

## Achievement artwork

Place the eight files named by each achievement's `artwork` field in `artwork/`. Every file must be:

- PNG format
- Exactly 1024 × 1024 pixels
- 8-bit RGB with no alpha channel or transparency
- At least 72 ppi when entered in App Store Connect
- A distinct Wuzzler achievement badge, not a leaderboard or app icon

Keep important artwork centered with generous edge clearance because Game Center may apply a mask. Do not add artwork to the four leaderboards; each leaderboard's `artwork` value is intentionally `null`.

Run the complete metadata and artwork check from the repository root:

```sh
python3 ReleaseAssets/GameCenter/validate.py
```

The check fails if any final PNG is missing or malformed. A passing check confirms identifiers, points, recurrence settings, leaderboard artwork policy, filenames, dimensions, bit depth, and opaque RGB color type.

## App Store Connect entry

Enter each achievement as visible and achievable once using its reference name, display name, point value, pre-earned description, earned description, and image from the manifest. Enter each leaderboard as recurring with its start set to the next UTC midnight before testing, a 24-hour duration and restart interval, low-to-high ordering, best-score submission, and elapsed-time formatting to hundredths of a second.
