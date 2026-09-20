# Releasing Mic Pause

## Prerequisites

- Xcode with the macOS 26 SDK or later; this release was verified with Xcode 27.
- XcodeGen: `brew install xcodegen`.
- Git and network access for the first pinned SwiftyDMG source build.
- SwiftyDMG **1.0.4**, upstream commit `844cf6291cb1102b08df5992fa0e4355b62eb964`. The packaging script builds and caches this exact source and verifies all dependency revisions. The executable is `swifty-dmg`; no JSON configuration is needed.
- A signing certificate and its private key in the local keychain.

The app’s version/build come from `project.yml`. Regenerate the project after changing them. Run the app tests, inspect the UI, and run the release preflight before tagging. Ensure the commit contains exactly the source used to build the artifact.

## SwiftyDMG compatibility

The upstream `hdiutil` wrapper treats any stderr output as an error. macOS 27 emits a deprecation warning even on a successful image operation. `script/build_swifty_dmg.sh` applies the checked-in `script/patches/swifty-dmg-hdiutil-exit-status.patch`: warnings remain visible, and a nonzero process exit still fails. It does not change the app or the Homebrew installation. The pinned tool lives outside the repository in a local temporary cache. `SWIFTY_DMG_BIN` can explicitly select another compatible build.

## Development-signed preview

```sh
./script/package_for_distribution.sh --preview
```

The default identity is `Apple Development`; set `DEVELOPMENT_IDENTITY` to its full name if several certificates match. A preview is **not notarized** and should be clearly marked as a GitHub **pre-release**. Recipients may encounter a Gatekeeper block. Do not describe it as a notarized release or a frictionless public download.

## Developer ID signed and notarized release

Install a **Developer ID Application** certificate with its private key and store your notarization credentials locally with `xcrun notarytool store-credentials`. Do not put credentials in this repository or release notes.

```sh
DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)' \
NOTARY_KEYCHAIN_PROFILE='your-local-profile' \
./script/package_for_distribution.sh --release
```

Release mode requires both settings. It signs with Hardened Runtime, submits the DMG to Apple, staples the notarization ticket, and checks Gatekeeper acceptance. A notarization failure stops packaging before the artifact is copied to `dist/`.

## What packaging verifies

The script stages sources outside iCloud, builds a Release app for **arm64 and x86_64**, signs it, and passes that app to [SwiftyDMG](https://github.com/chocoford/SwiftyDMG). It uses `--skipcodesign` so SwiftyDMG cannot silently pick a different signing identity. Release-mode DMG signing happens explicitly after packaging.

It verifies the disk image, mounts it read-only, checks the app signature, checks the Applications shortcut, and compares the packaged executable with the signed build. It then writes three files to `dist/`:

- `Mic-Pause-<version>[-preview.<build>]-universal.dmg`
- A matching `.sha256` checksum
- A matching `.INSTALL.txt` with signing status and installation instructions

Existing outputs are never overwritten. Set `OUTPUT_DIR` to a different directory for a new verification build. Open the mounted DMG in Finder to review its installation layout before publication.

## GitHub release

Commit and push first. Tag the exact source commit, then upload only the verified files. Example for the initial preview:

```sh
git tag -a v1.0-preview.1 -m 'Mic Pause 1.0 preview 1'
git push origin main v1.0-preview.1
gh release create v1.0-preview.1 --verify-tag --prerelease \
  --title 'Mic Pause 1.0 — Preview 1' \
  --notes-file docs/releases/v1.0-preview.1.md \
  dist/Mic-Pause-1.0-preview.1-universal.dmg \
  dist/Mic-Pause-1.0-preview.1-universal.sha256 \
  dist/Mic-Pause-1.0-preview.1-universal.INSTALL.txt
```

Use a fresh tag for each new binary. After upload, confirm the release’s commit, asset sizes, and downloaded asset SHA-256. GitHub pre-releases do not appear at `/releases/latest`, so the README links to `/releases`.

A private repository’s README and release downloads are available only to collaborators. Repository visibility is an owner decision; publishing a release does not change it.
