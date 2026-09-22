# Developing Mic Pause

## Project layout

- `MicPause/`: AppKit application shell, SwiftUI views, Core Audio monitoring, and Apple Music automation.
- `MicPauseTests/`: playback transitions, preference persistence, capture-source classification, and login-item tests.
- `project.yml`: XcodeGen source of truth. Commit the regenerated `MicPause.xcodeproj` after changing it.
- `AppStore/`: App Store preparation materials and screenshot harness. Store submission is a separate workflow from GitHub releases.
- `website/`: companion website source. Publishing it is separate from pushing the repository.

The current application target is intentionally not App Sandbox-enabled. Meeting Assist uses user-approved Accessibility access to supported meeting apps, which Apple documents as incompatible with App Sandbox. Hardened Runtime remains enabled. The materials under `AppStore/` predate Meeting Assist and are historical unless this capability is separated into a non-Store build.

Build caches and temporary screenshot projects belong in machine-local temporary storage, outside the iCloud source tree. `dist/` contains local release artifacts and is excluded from Git. Numbered duplicate Xcode project folders are retained locally but excluded; use `MicPause.xcodeproj`.

## Build and test

The scripts use `/Applications/Xcode.app/Contents/Developer` by default. Override `DEVELOPER_DIR` if needed. XcodeGen is required after adding or removing source files:

```sh
xcodegen generate
./script/test.sh
./script/build_and_run.sh --verify
```

The shared Debug scheme installs the signed app in `/Applications` after signing. `--logs`, `--telemetry`, and `--debug` are available on the build/run script. Tests, unsigned builds, and Release builds do not replace the installed Debug app.

## Icons

The app icon, menu-bar templates, and in-app brand mark share geometry in `MicPause/Views/MicPauseMark.swift`. Regenerate assets after changing that geometry:

```sh
./script/generate_app_icon.sh
```

## Screenshots

```sh
./script/capture_screenshot.sh dashboard
./script/capture_screenshot.sh settings

# Enlarged, borderless views focused on the primary README controls
./script/capture_screenshot.sh dashboard --readme
./script/capture_screenshot.sh settings --readme
```

The harness hosts the app’s real SwiftUI views under a separate bundle identifier. It does not opt into Launch at Login. Capture only its window; keep personal information and unrelated windows out of repository images. README screenshots are stored in `docs/images/`. In `--readme` mode, activate the window before capture so controls use their active appearance. The view is enlarged 1.5× and cropped to its primary controls to fit a laptop display; this does not change the production app. Display the resulting captures below their pixel width in the README for sharper text. The editable SVG banner uses the app’s existing mark geometry.

Historical App Store compositions are in `AppStore/Screenshots/`; recapture and review them before a Store submission.

## Website

```sh
cd website
npm ci
npm test
```

The app itself has no third-party runtime packages. The website has its own npm dependency tree and is not embedded in the app.
