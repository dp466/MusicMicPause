# Mic Pause

Mic Pause is a native macOS menu-bar utility that pauses Apple Music when the
current default microphone becomes active. When the microphone becomes inactive,
it resumes Apple Music only if Mic Pause initiated the pause.

It reads only Core Audio device activity state. It does not open an audio stream,
record or analyze audio, store audio, use the network, simulate media keys, or
request Accessibility access.

## Requirements

- macOS 14 or later
- Xcode 27 beta at `/Applications/Xcode-beta.app`
- Apple Music

## Build and run

Generate the Xcode project after changing `project.yml`:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodegen generate
```

Build and launch:

```sh
./script/build_and_run.sh
```

The script uses Xcode 27 beta without changing the machine-wide `xcode-select`
setting. The Codex Run action is wired to the same script.

## Test

```sh
./script/test.sh
```

The unit tests cover playing and already-paused Music, manual playback changes,
input-device changes, noisy notifications, automation failures, preference
persistence, shutdown cleanup, and stale asynchronous transitions.

## Permissions

The first attempt to control Apple Music causes macOS to ask whether Mic Pause
may automate Music. Permission can be reviewed under **System Settings → Privacy
& Security → Automation**. Mic Pause has no microphone usage description because
it never captures audio; the public Core Audio device-running property does not
require recording permission.

Launch at login uses `SMAppService.mainApp`. It is intended for a properly signed
app copied into Applications; behavior from an ad-hoc-signed development build
may vary.

## App Store preparation

The project includes an App Sandbox entitlement, Hardened Runtime, a privacy
manifest, a complete macOS app-icon set, a utility category, an encryption-use
declaration, an in-app privacy policy, App Review notes, upload-ready screenshots,
complete App Store copy, and a release website. Start with
[`AppStore/ReleaseReadiness.md`](AppStore/ReleaseReadiness.md), then follow
[`AppStore/SubmissionChecklist.md`](AppStore/SubmissionChecklist.md).

Run the full local release preflight with:

```sh
./script/validate_release.sh
```

After configuring the Apple Developer team and installing a supported release
Xcode, create the signed archive with:

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID ./script/archive_app_store.sh
```

Development and automated verification use Xcode 27 beta as requested. Create
the final distribution archive with a currently App Store-supported stable Xcode
release and your Apple Distribution signing team.

## Known limitations

- Core Audio reports whether the selected input device is performing I/O, not
  which process opened it. A driver that keeps the device running will keep Music
  paused. The device-running property is observed at global scope because some
  drivers accept an input-scoped listener but never deliver activity changes to
  it. A one-second safety refresh covers drivers that occasionally omit property
  notifications.
- Apple Music does not expose a reliable event identifying who changed playback.
  Mic Pause polls while it owns a pause so a manual resume is respected, but a
  resume-and-pause sequence shorter than the polling interval is not observable.
- The sandboxed build uses Music’s narrow `com.apple.Music.playback` scripting
  access group for its play, pause, and playback-state Apple Events.
- Bluetooth and disconnected devices are rebound when Core Audio changes the
  default input. During the transition the menu reports that monitoring is
  unavailable.
