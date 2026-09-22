import Link from "next/link";

export const metadata = {
  title: "Privacy Policy",
  description: "How Mic Pause protects your privacy.",
};

export default function PrivacyPage() {
  return (
    <main className="legalPage">
      <nav className="nav shell" aria-label="Privacy navigation">
        <Link className="brand" href="/">
          ← Mic Pause
        </Link>
        <Link href="/support">Support</Link>
      </nav>

      <header className="legalHero shell">
        <p className="eyebrow">PRIVACY POLICY</p>
        <h1>Nothing to collect.</h1>
        <p>
          Mic Pause is designed to work entirely on your Mac. It does not
          collect, store, sell, or transmit personal data.
        </p>
      </header>

      <article className="legalContent shell">
        <h2>Microphone activity</h2>
        <p>
          Mic Pause reads microphone activity and capture-process identifiers
          reported by Core Audio. It does not open an audio stream, record
          audio, access the content of conversations, or analyze sound.
        </p>

        <h2>Apple Music automation</h2>
        <p>
          With your permission, Mic Pause sends play, pause, and player-state
          commands to the Apple Music app through macOS Automation. It does not
          access your music library, listening history, or Apple Account.
        </p>

        <h2>Meeting controls and Phone calls</h2>
        <p>
          When you enable Meeting Assist or Phone-call detection and grant
          Accessibility permission, Mic Pause reads control roles, labels,
          enabled states, and available actions in supported meeting apps. It
          presses only a verified Mute or Unmute control. It may read whether
          Phone or FaceTime exposes an enabled Hang Up control to recognize a
          call, but it never presses that control.
        </p>

        <h2>System volume</h2>
        <p>
          Meeting Assist can temporarily lower the default output device’s
          software volume. It restores only the exact value it changed and
          leaves a manual volume change alone.
        </p>

        <h2>Feedback sounds</h2>
        <p>
          If enabled, Mic Pause plays brief locally generated tones for Music
          and meeting-microphone changes. The tones contain no microphone audio
          and are off by default.
        </p>

        <h2>Settings</h2>
        <p>
          Your monitoring, playback, Meeting Assist, Phone-call detection,
          feedback-sound, and ignored-source preferences are stored locally on
          your Mac using standard system preferences.
        </p>

        <h2>Accounts, analytics, and networking</h2>
        <p>
          Mic Pause has no user accounts, advertising, third-party analytics,
          tracking, or network functionality.
        </p>

        <h2>Changes</h2>
        <p>
          If the app’s privacy practices change, this policy and any applicable
          distribution privacy disclosure will be updated before those changes
          are released.
        </p>

        <h2>Contact</h2>
        <p>
          Questions about this policy can be sent through the contact method on
          the <Link href="/support">support page</Link>.
        </p>

        <p>Effective date: September 22, 2026</p>
      </article>
    </main>
  );
}
