<p align="center">
  <img src="docs/images/readme-banner.svg" width="100%" alt="Mic Pause — Quiet music. Clear conversations. A native Mac app that pauses Apple Music when your microphone is in use.">
</p>

<p align="center">
  <strong>macOS 14+</strong> &nbsp;·&nbsp; Apple silicon &amp; Intel &nbsp;·&nbsp; Built with Swift &amp; SwiftUI
</p>
<p align="center">
  <a href="https://github.com/dp466/MusicMicPause/releases"><strong>Download the preview →</strong></a> &nbsp;·&nbsp;
  <a href="#getting-started">Get started</a> &nbsp;·&nbsp;
  <a href="#privacy">Privacy</a> &nbsp;·&nbsp;
  <a href="https://github.com/dp466/MusicMicPause/issues">Report an issue</a>
</p>

## Music that makes room for you

Start a call, record a voice note, or use dictation. **Mic Pause automatically pauses Apple Music while your microphone is active**, then resumes it when you’re done. It lives in your menu bar, ready whenever you need it.

| Your music, your control | Built for everyday use |
| --- | --- |
| **Resume on your terms.** Choose immediately, 1, 2, or 5 seconds—or disable automatic resume. | **Choose what counts.** Review active microphone sources and ignore individual apps. |
| **Manual pauses stay paused.** Music resumes only if Mic Pause initiated the pause. | **One click away.** Open the dashboard from the menu bar; right-click for quick actions. |
| **Override any session.** Manually resume Music and Mic Pause leaves playback alone for that microphone session. | **Ready at login.** Launch at Login is enabled on first launch and can be switched off. |
| **Meeting Assist.** Lower call audio while dictating into ChatGPT, macOS Dictation, or MacWhisper. | **State-aware muting.** With permission, mute Teams, Zoom, FaceTime, or Phone without sending a blind keyboard toggle. |

## A small app, with the controls you need

<table>
  <tr>
    <th>See what’s happening</th>
    <th>Set your own rhythm</th>
  </tr>
  <tr>
    <td align="center" valign="top"><img src="docs/images/dashboard.jpg" width="340" alt="Mic Pause dashboard: microphone is quiet, automatic resume is enabled, and the resume delay is set to two seconds."></td>
    <td align="center" valign="top"><img src="docs/images/settings.jpg" width="460" alt="Mic Pause settings: monitoring, launch at login, automatic resume, and a choice of four resume delays."></td>
  </tr>
  <tr>
    <td>Microphone status and playback controls at a glance.</td>
    <td>Monitoring, startup, and playback preferences in one place.</td>
  </tr>
</table>

<sub>Captured from the app’s native views on macOS 27. Images focus on the primary controls; additional settings are available by scrolling. Appearance varies with macOS.</sub>

## Getting started

1. **[Download the DMG](https://github.com/dp466/MusicMicPause/releases)** for the latest preview.
2. Drag **Mic Pause** into **Applications**, then eject the disk image.
3. Open Mic Pause and click its microphone icon in the menu bar.
4. Allow it to control **Music** when macOS asks. Play some music, then start using your microphone.
5. Optional: enable **Meeting Assist** and grant Accessibility permission if you want call audio lowered and the meeting microphone muted during dictation.

The default recovery delay is **two seconds**. It applies to both automatic Music resume and Meeting Assist's meeting unmute and sound restoration. Meeting Assist mutes promptly when dictation starts; it does not wait before protecting your prompt. Optional feedback tones for Music and meeting-microphone changes are off until you enable them in Settings. Mic Pause controls the **Music app on your Mac**. Meeting Assist can temporarily lower the current system output, but it does not control Spotify or browser playback directly. Local music playback does not require an Apple Music subscription.

> **Preview signing:** the current preview is development-signed and **not notarized by Apple**. macOS may block it. Read the release’s installation notes before installing. If you trust the download, macOS provides **System Settings → Privacy & Security → Open Anyway** after an attempted launch.

<details>
<summary>Verify your download</summary>

Each release includes a SHA-256 checksum. Put the DMG and its `.sha256` file in the same folder, then run:

```sh
shasum -a 256 -c Mic-Pause-1.0-preview.1-universal.sha256
```

Use the filename supplied with your release. A matching checksum confirms the file matches the published download; it does not replace code signing or notarization.

</details>

## Privacy

**No audio recordings. No accounts. No analytics.**

Mic Pause reads Core Audio activity metadata to learn whether a microphone is active and which capture processes macOS reports. It does not open an audio stream or analyze your conversations. Meeting Assist can read the role, label, enabled state, and available action of controls in supported meeting apps, and press a verified Mute or Unmute control. Phone-call detection reads whether Phone or FaceTime exposes an enabled Hang Up control; it never presses that control. The app makes no network requests, and preferences stay on your Mac.

It requests **Automation permission for Music**. Accessibility is optional and is used only when Meeting Assist or Phone-call detection is enabled. It does not request microphone-recording or screen-recording permission.

[Read the privacy policy](docs/privacy.html) · [Inspect the privacy manifest](MicPause/PrivacyInfo.xcprivacy)

## Questions & troubleshooting

<details>
<summary><strong>Music doesn’t pause or resume</strong></summary>

- Enable monitoring and check Apple Music permission in Settings. If denied, review **System Settings → Privacy & Security → Automation → Mic Pause**.
- For resume, enable automatic resume and wait for the selected delay. Mic Pause must have initiated the pause, and the microphone must be inactive.
- A capture source that stays active can keep Music paused. Review **Settings → Microphone Sources**.

</details>

<details>
<summary><strong>The microphone appears to be always active</strong></summary>

Some apps and drivers keep an input open between calls. Review **Settings → Microphone Sources** and ignore a source only when you want its microphone use to leave Music playing.

Known background listeners are ignored by default. Dictation and Siri still trigger a pause unless you explicitly ignore them.

Detection depends on macOS and audio-driver activity reports. The app listens for system-wide capture-process changes, including apps using a non-default microphone, and keeps a one-second fallback refresh. When attribution is unavailable, it falls back to the default input’s activity flag.

</details>

<details>
<summary><strong>Meeting Assist did not lower or mute the call</strong></summary>

- Enable Meeting Assist in Settings and allow Mic Pause in **System Settings → Privacy & Security → Accessibility**.
- Native-app microphone control currently supports Microsoft Teams, Zoom, FaceTime, and Phone. Mic Pause intentionally does not send blind keyboard shortcuts. If it cannot verify a Mute/Unmute control, it leaves the app alone and reports the problem in Settings.
- Mic Pause waits for the selected **Music & Meeting Recovery Delay** after dictation ends before unmuting a microphone it muted and restoring reduced sound. If you want confirmation tones, turn on **Play feedback sounds** in Settings; the tones are off by default and may be audible to other meeting participants after unmuting.
- Sound reduction uses the default output device’s public software-volume control. Some fixed-volume hardware and virtual devices—including some Wave Link routes—do not expose one; Mic Pause reports that limitation instead of changing an unrelated control.
- Browser meetings are not auto-muted because a browser bundle identifier does not safely identify which tab owns the meeting.

</details>

<details>
<summary><strong>An iPhone call in the Mac Phone app is not detected</strong></summary>

Continuity calls are relayed through the iPhone, and their audio can be owned by private Apple telephony services rather than the visible Phone app. Native macOS apps also cannot use CallKit’s system call observer. This explains why Mic Pause—and sometimes “record all system audio” tools—may see neither a Phone microphone process nor call audio.

On supported macOS versions, Mic Pause offers a best-effort Accessibility fallback: it treats Phone or FaceTime as active only while macOS exposes an enabled **Hang Up** control. Grant Accessibility permission and keep **Detect active Phone calls** enabled. If macOS does not expose that control for a particular call route or version, the call remains a known platform limitation.

</details>

<details>
<summary><strong>I can’t find the app, or Launch at Login needs approval</strong></summary>

Mic Pause has no Dock icon. Check the menu bar and any menu-bar hiding utility. For startup approval, review **System Settings → General → Login Items**. Install the app in Applications before enabling Launch at Login.

</details>

Still stuck? [Open an issue](https://github.com/dp466/MusicMicPause/issues) with your macOS version, app version, microphone, and steps to reproduce.

## Build from source

Use **Xcode 26+ with the macOS 26 SDK or newer** and [XcodeGen](https://github.com/yonaskolb/XcodeGen). This checkout is verified with Xcode 27; the app runs on macOS 14+ and adopts newer visual effects where supported.

Meeting Assist uses user-approved Accessibility control of other apps. Apple documents assistive Accessibility access as incompatible with App Sandbox, so the current target is a Hardened Runtime, direct-distribution build and is not ready for the Mac App Store without separating or removing that feature.

```sh
brew install xcodegen
git clone https://github.com/dp466/MusicMicPause.git
cd MusicMicPause
xcodegen generate
./script/build_and_run.sh --verify
```

Select your signing team in Xcode. The script defaults to `/Applications/Xcode.app`; set `DEVELOPER_DIR` to choose another installation. Signed Debug builds install into `/Applications/MicPause.app`, replacing an existing development copy.

```sh
./script/test.sh              # Native app tests
./script/validate_release.sh  # App and website preflight
```

[Development guide](docs/DEVELOPMENT.md) · [Release & SwiftyDMG packaging guide](docs/RELEASING.md)

---

Made by [Dilan Paradis](https://github.com/dp466). Mic Pause is an independent utility and is not affiliated with Apple.
