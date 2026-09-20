# Mic Pause Support

For questions, bug reports, or feature requests, email
**dparadis466@gmail.com**.

Please include your macOS version, Mic Pause version, microphone model, and a
short description of what happened.

## Apple Music is not pausing

1. Open Mic Pause from the menu bar and confirm monitoring is on.
2. Open Settings and select **Check Permission**.
3. If needed, open **System Settings → Privacy & Security → Automation** and
   allow Mic Pause to control Music.
4. Start playback in Apple Music and try your microphone again.

## The microphone is not detected

Check **Settings → Microphone Sources** and ensure the app is not ignored.
Mic Pause checks system-wide capture activity, including non-default inputs.
When process information is unavailable, it falls back to the default input.

## Music did not resume

Mic Pause resumes only when it initiated the pause. It intentionally respects
music you paused yourself. Also confirm that **Resume automatically** is enabled
in Settings.

## Privacy

Mic Pause reads microphone activity and capture-process metadata. It does
not open an audio stream, record audio, analyze conversations, or transmit
data.
