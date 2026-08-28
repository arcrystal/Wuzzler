# Xcode Security Audit Status

Date: 2026-08-28
Project: Wuzzler
Active scheme: Wuzzler

## Scope

This note records the security posture for Wuzzler Daily 1.0. The full release procedure and external gates are in `Docs/TestFlightRelease.md`.

## Current State

- App target: Wuzzler
- Bundle identifier: CotterCrystal.Wuzzler
- Version/build: 1.0 (1)
- Deployment target: iOS 17.0
- Code signing: Automatic, team VD6A5NU7DP
- Entitlements file: Wuzzler/Wuzzler.entitlements
- Existing entitlement: com.apple.developer.game-center = true
- Privacy manifest: tracking disabled, no collected data types, UserDefaults reason CA92.1
- Export compliance: non-exempt encryption is disabled because the app has no custom cryptography
- Remote puzzle content: exact HTTPS GitHub Pages host and manifest path only
- ENABLE_ENHANCED_SECURITY: NO
- ENABLE_POINTER_AUTHENTICATION: NO through ENABLE_ENHANCED_SECURITY
- CLANG_ENABLE_STACK_ZERO_INIT: NO through ENABLE_ENHANCED_SECURITY
- ENABLE_SECURITY_COMPILER_WARNINGS: NO through ENABLE_ENHANCED_SECURITY
- No xcconfig files found.

## Enhanced Security Deferral

Deferred for this beta build because the active signing team is a personal development team and provisioning does not support the Enhanced Security capability for `CotterCrystal.Wuzzler`.

- Do not enable `ENABLE_ENHANCED_SECURITY` until the app is signed with a team/provisioning profile that supports Enhanced Security.
- Do not add hardened-process entitlements under the current provisioning profile.
- Keep the existing Game Center entitlement unchanged.

## Deferred Hardening Items

When signing supports it, enable Enhanced Security for the app target and add the documented hardened-process entitlements:

- `ENABLE_ENHANCED_SECURITY = YES`
- `com.apple.security.hardened-process = true`
- `com.apple.security.hardened-process.enhanced-security-version-string = 2`
- `com.apple.security.hardened-process.dyld-ro = true`
- `com.apple.security.hardened-process.platform-restrictions-string = 2`

## Release Validation

The release gate validates puzzle coverage, runs unit and interface tests, creates an unsigned archive, and checks the bundle identity, version, deployment target, privacy manifest, encryption declaration, icon opacity, entitlement source, and dSYM. A signed App Store archive and physical-device verification remain mandatory before distribution.

## Notes

Apple documentation warns that Enhanced Security can affect stability and performance if an app is not already compatible with its runtime checks. This project appears mostly SwiftUI/Swift and does not show custom allocators, Mach IPC, or dynamic-library loading in the audited app code, so the initial risk looks acceptable once provisioning supports the capability, but device testing after enabling it is still required.
