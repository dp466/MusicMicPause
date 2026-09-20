# App Review Notes

Mic Pause is a menu-bar utility. It has no Dock icon and opens from the
microphone icon in the macOS menu bar.

No account or demo credentials are required.

## Core behavior

1. Launch Apple Music and begin playing a song.
2. Launch Mic Pause and allow its Apple Music Automation request.
3. Start using the current default microphone in an app such as FaceTime,
   QuickTime Player, or a voice-recording app.
4. Mic Pause pauses Apple Music while the Core Audio input device reports that
   it is running.
5. Stop using the microphone. Mic Pause resumes Music after the selected delay,
   but only if Mic Pause initiated the pause.

Mic Pause reads public Core Audio device activity and capture-process metadata. It does not open
an audio input stream and therefore does not capture or record microphone audio.
It sends only `play`, `pause`, and `player state` Apple Events to Music through
the `com.apple.Music.playback` scripting access group.

The app has no accounts, purchases, analytics, advertising, or network
functionality.

## Permissions

Mic Pause does not request macOS microphone-recording permission because it
does not capture microphone audio. The only permission prompt expected during
review is Automation access to control Music.

If the Automation prompt was previously denied, open System Settings → Privacy
& Security → Automation and enable Music under Mic Pause, then return to Mic
Pause Settings and choose Check Permission.
