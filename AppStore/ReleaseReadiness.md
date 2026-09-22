# Mic Pause 1.0 Release Readiness

> Historical App Store preparation notes from July 2026. The current main target adds Accessibility-based Meeting Assist and is intentionally unsandboxed, so this readiness snapshot no longer describes the build. Split or remove that capability and restore App Sandbox before pursuing the Store path. For current GitHub packaging and signing, see [release instructions](../docs/RELEASING.md).

## Ready now

- Three App Store screenshots are complete at 2560 × 1600.
- App Store copy, privacy answers, age-rating guidance, and review notes are
  prepared.
- Version 1.0 is configured in the release metadata as free.
- App Sandbox, Hardened Runtime, Apple Music Automation entitlement, Developer
  Team `QU4R4G95KN`, privacy
  manifest, app icon, version, category, and encryption declaration are in
  place.
- A release website with marketing, privacy, and support routes is ready to
  publish.
- Automated app tests and the website build/tests pass with Xcode 27 beta and
  Node.js.
- The public support email is configured on the prepared support page.

## Blocking submission

1. The supplied Gist is for iPerf Pulse, not Mic Pause. Publish the prepared
   website or create a separate public Gist from `MicPauseSupport.md`.
2. The privacy and support pages still need public HTTPS URLs.
3. Only Xcode 27 beta build `27A5194q` is installed. As of July 28, 2026, Apple
   accepts Xcode 27 beta 4 for TestFlight only. Use Xcode Cloud with an accepted
   release Xcode for the App Store archive, or wait until Apple explicitly
   enables Xcode 27 for production submissions.
4. This Mac has an Apple Development identity but no Apple Distribution
   identity. Xcode Cloud automatic signing avoids requiring that identity
   locally.
5. Storefront availability, App Review contact information, and DSA trader
   status remain owner/account decisions.

Follow `XcodeCloudSubmission.md` for the recommended release path from the
current development-beta Mac.
