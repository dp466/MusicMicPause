# App Review Notes

Mic Pause is a menu-bar utility. It has no Dock icon and opens from the
microphone icon in the macOS menu bar.

## Core behavior

1. Launch Apple Music and begin playing a song.
2. Launch Mic Pause and allow its Apple Music Automation request.
3. Start using the current default microphone in an app such as FaceTime,
   QuickTime Player, or a voice-recording app.
4. Mic Pause pauses Apple Music while the Core Audio input device reports that
   it is running.
5. Stop using the microphone. Mic Pause resumes Music after the selected delay,
   but only if Mic Pause initiated the pause.

Mic Pause reads the public Core Audio device-running property. It does not open
an audio input stream and therefore does not capture or record microphone audio.
It sends only `play`, `pause`, and `player state` Apple Events to Music through
the `com.apple.Music.playback` scripting access group.

The app has no accounts, purchases, analytics, advertising, or network
functionality.
