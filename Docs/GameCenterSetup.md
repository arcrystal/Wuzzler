# Wuzzler Game Center Setup

Configure these records in App Store Connect before TestFlight scoring can work.

## Recurring Leaderboards

- `wuzzler.diagone.daily`
- `wuzzler.rhymeagrams.daily`
- `wuzzler.tumblepuns.daily`
- `wuzzler.sweep.daily`

Settings:

- Recurrence start: the next UTC midnight before external testing
- Duration: `24h`
- Restart: `24h`
- Sort: low score wins
- Submission: best score
- Score format: elapsed time
- Submitted value: centiseconds as `Int64`
- Leaderboard artwork: none

## Achievements

- `wuzzler.achievement.first_solve`
- `wuzzler.achievement.first_daily_sweep`
- `wuzzler.achievement.streak_7`
- `wuzzler.achievement.streak_14`
- `wuzzler.achievement.streak_30`
- `wuzzler.achievement.diagone_first_solve`
- `wuzzler.achievement.rhymeagrams_first_solve`
- `wuzzler.achievement.tumblepuns_first_solve`

Settings:

- Visible and achievable once
- `first_solve`: 10 points
- `first_daily_sweep`: 25 points
- `streak_7`: 50 points
- `streak_14`: 75 points
- `streak_30`: 100 points
- Each game-specific first solve: 10 points
- Use distinct Wuzzler badge artwork for achievements only; do not add artwork to leaderboards.

Before distributing a build, compare every App Store Connect identifier, recurrence setting, score format, and point value above against the live record. Test daily-score submission with two sandbox accounts and verify that archived/practice solves never submit.

## Content Export

Before each TestFlight build:

```sh
Scripts/validate_puzzles.py --minimum-future-days 30
Scripts/export_content_manifest.py --minimum-future-days 30 --output build/content/v1/puzzles.json
```

The Pages workflow publishes the exported file to `https://arcrystal.github.io/Wuzzler/content/v1/puzzles.json` after validation succeeds.
