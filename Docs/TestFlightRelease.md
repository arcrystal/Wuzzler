# Wuzzler Daily TestFlight Release

## One-time account setup

1. Reserve **Wuzzler Daily** in App Store Connect using bundle ID `CotterCrystal.Wuzzler`, SKU `wuzzler-daily-ios`, primary language English (U.S.), and Games → Word.
2. Enable Game Center for the explicit App ID and configure the records in `GameCenterSetup.md`.
3. Enable GitHub Pages with **GitHub Actions** as its source. Confirm the privacy, support, and puzzle-content URLs return successfully over HTTPS.
4. Enter the Pages privacy/support URLs in App Store Connect. Enter a verified private feedback email and an international-format review phone number directly in App Store Connect.
5. Complete the age-rating and App Privacy questionnaires from the current data map. No account is required; Game Center is optional; there is no chat, advertising, purchasing, tracking, or unrestricted web browsing.
6. Install stable Xcode 26.6, sign in to the correct Apple developer account, and allow automatic signing to create or select an Apple Distribution identity and App Store profile. CI uses the matching Xcode 26.6 toolchain on GitHub's macOS 26 image.

## Prepare a candidate

1. Confirm the worktree is clean and `main` contains the intended release state.
2. Run `Scripts/validate_puzzles.py --minimum-future-days 30`.
3. Confirm the iOS release-gate and Pages workflows pass.
4. Run `Scripts/prepare_testflight_build.sh`, review the integer build-number change, and commit it.
5. Tag the commit as `testflight/1.0.<build>`.
6. Re-run the full test suite on that exact commit.

## Archive and upload

1. In Xcode, select **Any iOS Device (arm64)** and Product → Archive.
2. Run `Scripts/audit_release_archive.sh` against the Organizer archive path.
3. In Organizer, choose Distribute App → App Store Connect → Upload. Do not select “TestFlight Internal Only.”
4. Resolve every validation warning before upload. Confirm the processed build includes its dSYM, privacy manifest, Game Center entitlement, version, and build number.
5. Answer export compliance consistently with `ITSAppUsesNonExemptEncryption = NO`; re-audit this answer if custom cryptography is ever introduced.

## External beta

1. Create an internal group named **Release QA**, install the processed build, and complete the physical-device smoke test.
2. Create an external **Public Beta** group with an initial public-link limit of 100 and iOS 17+ criteria.
3. Beta description: “Wuzzler Daily brings together three original daily word puzzles—Diagone, RhymeAGram, and TumblePun—with archives, local progress, and optional Game Center competition.”
4. What to Test: guest onboarding, Game Center sign-in, all three daily games, archives, loading transitions and haptics, progress restoration, leaderboards, reminders, appearance modes, and TestFlight feedback.
5. Review notes: “No account is required. All puzzles can be played as a guest. Game Center is optional and is used only for friends, leaderboards, and achievements.”
6. Submit the first build for TestFlight App Review and enable automatic tester notification after approval.

## Go/no-go checklist

- Complete each game from a cold launch on a physical iPhone and verify the loading transition and first haptic have no visible stall.
- Exercise background/foreground timing, offline launch, notification allowed/denied, light/dark appearance, Dynamic Type, VoiceOver, Reduce Motion, and Reduce Transparency.
- Verify guest play and later Game Center sign-in. With two sandbox accounts, confirm friends/global rankings, centisecond formatting, score deduplication, and achievements.
- Verify compact and standard iPhone, large iPhone, and iPad portrait layouts.
- Confirm no blocker or high-severity issue, no launch/solve crash, 30 days of continuous content, and a healthy published endpoint.

## Rollback and expiration

- To roll back puzzle content, revert the content commit and let the Pages workflow redeploy the last valid manifest.
- To stop a bad binary, remove it from tester groups and expire it in TestFlight; never reuse its build number.
- Keep each superseded candidate available only until its replacement has passed smoke testing, then expire it to prevent accidental installs.
