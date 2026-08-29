# Wuzzler Daily TestFlight Release

## 1. Finish the Apple account setup

1. Reserve **Wuzzler Daily** in App Store Connect using bundle ID `CotterCrystal.Wuzzler`, SKU `wuzzler-daily-ios`, primary language English (U.S.), and Games → Word.
2. Enable Game Center for the explicit App ID and configure every record in `GameCenterSetup.md` before testing scores.
3. Enable GitHub Pages with **GitHub Actions** as its source. Confirm the privacy, support, and puzzle-content URLs return successfully over HTTPS.
4. Enter those privacy/support URLs in App Store Connect. Enter a verified private feedback email and an international-format review phone number directly in App Store Connect.
5. Complete the age-rating and App Privacy questionnaires. No account is required; Game Center is optional; there is no chat, advertising, purchasing, tracking, or unrestricted web browsing.
6. Create an internal TestFlight group named **Release QA**. After its first processed build, create the external **Public Beta** group with iOS 17+ criteria and a public-link limit of 100.

## 2. Prepare Xcode 27 beta 6 and signing

1. Use Xcode 27 beta 6 (`27A5252f`) for preview testing. Keep the app deployment target at iOS 17 and Swift language mode at Swift 5.
2. Leave the global Command Line Tools selection unchanged. Run beta-specific commands with an explicit developer directory and verify the exact build:

   ```sh
   DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
     xcodebuild -version
   ```

   The reported build must be `27A5252f`. Launch `/Applications/Xcode-beta.app` directly for interactive beta work; do not use `sudo xcode-select` to make it the system-wide default.
3. Sign in to the Apple developer account for team `VD6A5NU7DP`. Replace any expired development identity, create or obtain an Apple Distribution identity, and let automatic signing create or select profiles for `CotterCrystal.Wuzzler` with Game Center.
4. Confirm Xcode can run Wuzzler on a physical device before preparing a candidate. The project must not be migrated to an iOS 27 deployment target or Swift 6 merely because it is opened in Xcode 27.

## 3. Keep both automated toolchain lanes healthy

- The required **Xcode 26.6 release baseline** runs all content tests, iOS tests, an unsigned Release archive, and archive inspection.
- The **Xcode 27 preview advisory** runs the same shared gate on GitHub's current `xcode-27` image and records its actual Xcode/SDK versions. GitHub may publish a preview image later than Apple, so a local beta 6 gate is required even when the advisory lane is green.
- Run the exact local gate before distributing a beta:

  ```sh
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
    Scripts/run_release_gate.sh \
      --lane xcode27-beta6-local \
      --output-dir /tmp/Wuzzler-xcode27-beta6-gate \
      --expected-xcode-build 27A5252f \
      --expected-sdk iphoneos27.0
  ```

- Do not distribute while the required Xcode 26.6 lane or the local Xcode 27 beta 6 gate is failing. Treat a preview CI failure as a compatibility issue to investigate even though it is advisory in branch protection.

## 4. Prepare an immutable candidate

1. Confirm the Pages and iOS workflows are green and the published endpoint has at least 30 continuous future days for every game.
2. In App Store Connect, find the greatest build number ever uploaded for version 1.0. Choose a positive integer greater than that number and confirm it has never been used.
3. Start from a clean, synchronized `main`. The preparation script rejects another branch, a dirty tree, a local/remote mismatch, a decreasing number, or an existing local/remote release tag:

   ```sh
   Scripts/prepare_testflight_build.sh <build-number> --app-store-confirmed
   ```

4. Review and commit the build-number change. If the selected build was already committed, use the existing clean commit.
5. Re-run the Xcode 26.6 workflow and the local Xcode 27 beta 6 gate on that exact commit.
6. Tag only the passing commit as `testflight/1.0.<build-number>` and push the commit and tag. Never move or reuse a TestFlight tag.

## 5. Sign, inspect, and distribute

### Preferred: Xcode Cloud

1. Create a workflow named **TestFlight Beta** for the `main` branch. Select Xcode 27 beta 6 exactly when Xcode Cloud offers it; if it does not, keep Xcode Cloud distribution disabled and use the exact local beta 6 archive path below. Use the Wuzzler scheme, an iOS archive action, Apple-managed signing, and TestFlight distribution to the internal **Release QA** group.
2. Start the workflow manually from the exact tagged commit. Do not enable a TestFlight-internal-only restriction if the same build will later go to external testers.
3. Confirm the processed App Store Connect build reports the committed version/build, iOS 17 minimum, expected Xcode/SDK, Game Center capability, privacy manifest, and dSYM. A mismatch is a failed candidate; do not retag or reuse its number.

### Fallback: local Organizer upload

1. Open `/Applications/Xcode-beta.app`, select **Any iOS Device (arm64)**, and choose Product → Archive.
2. Inspect the signed archive before distribution, substituting the selected build number:

   ```sh
   Scripts/audit_release_archive.sh /path/to/Wuzzler.xcarchive \
     --expected-build <build-number> \
     --expected-xcode-build 27A5252f \
     --expected-sdk iphoneos27.0 \
     --require-signed
   ```

3. In Organizer, choose Distribute App → App Store Connect → Upload. Do not select **TestFlight Internal Only**. Resolve every validation warning.
4. Answer export compliance consistently with `ITSAppUsesNonExemptEncryption = NO`; reassess this answer if custom cryptography is introduced.

## 6. TestFlight rollout and acceptance

1. Install the processed build through **Release QA**. Complete each game from a cold launch on a physical iPhone and verify the loading transition and first haptic do not stall.
2. Exercise background/foreground timing, offline launch, notification allowed/denied, light/dark appearance, Dynamic Type, VoiceOver, Reduce Motion, Reduce Transparency, and iPhone/iPad layouts.
3. Verify guest play and later Game Center sign-in. With two sandbox accounts, confirm friends/global rankings, centisecond formatting, score deduplication, queued-score flushing, and all achievements.
4. Add the same build to **Public Beta** only after the internal smoke passes. Use:
   - Beta description: “Wuzzler Daily brings together three original daily word puzzles—Diagone, RhymeAGram, and TumblePun—with archives, local progress, and optional Game Center competition.”
   - What to Test: guest onboarding, Game Center sign-in, all three daily games, archives, loading transitions and haptics, progress restoration, leaderboards, reminders, appearance modes, and TestFlight feedback.
   - Review notes: “No account is required. All puzzles can be played as a guest. Game Center is optional and is used only for friends, leaderboards, and achievements.”
5. Submit the first external build for Beta App Review and enable automatic tester notification after approval. Release only when no blocker/high-severity issue remains and the public link installs successfully.

## 7. Cut over to stable Xcode 27

1. When Apple releases Xcode 27 RC/final and App Store Connect accepts that toolchain, pin the local and Xcode Cloud release workflows to it. Do not submit a beta-built binary as the App Store release.
2. Add a temporary required GitHub lane pinned to exact Xcode 27 stable. Run it alongside Xcode 26.6 and the preview lane once.
3. Increment to a new unused build number, rebuild from the intended clean source commit with stable Xcode 27, repeat automated and physical-device QA, then upload a new candidate.
4. After the stable Xcode 27 lane and signed archive pass, replace the Xcode 26.6 baseline with stable Xcode 27 and remove the preview lane. Keep iOS 17 and Swift 5 until a separate compatibility decision changes them.
5. Update this runbook with the exact stable Xcode build and SDK recorded in the accepted archive.

## Rollback and expiration

- To roll back puzzle content, revert the content commit and let Pages redeploy the last valid manifest.
- To stop a bad binary, remove it from tester groups and expire it in TestFlight; never reuse its build number.
- Keep each superseded candidate available only until its replacement passes smoke testing, then expire it to prevent accidental installs.
