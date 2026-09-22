import Link from "next/link";

export const metadata = {
  title: "Support",
  description: "Help and contact information for Mic Pause.",
};

export default function SupportPage() {
  return (
    <main className="legalPage">
      <nav className="nav shell" aria-label="Support navigation">
        <Link className="brand" href="/">
          ← Mic Pause
        </Link>
        <Link href="/privacy">Privacy</Link>
      </nav>

      <header className="legalHero shell">
        <p className="eyebrow">SUPPORT</p>
        <h1>Let’s get you back in flow.</h1>
        <p>
          Most issues can be fixed by checking microphone monitoring and Apple
          Music Automation permission.
        </p>
      </header>

      <article className="legalContent shell">
        <h2>Apple Music is not pausing</h2>
        <ol>
          <li>Open Mic Pause from the menu bar and confirm monitoring is on.</li>
          <li>Open Settings and select Check Permission.</li>
          <li>
            If needed, open System Settings → Privacy &amp; Security →
            Automation and allow Mic Pause to control Music.
          </li>
          <li>Start playback in Apple Music and try your microphone again.</li>
        </ol>

        <h2>The microphone is not detected</h2>
        <p>
          Check Settings → Microphone Sources and ensure the app is not ignored.
          Mic Pause checks system-wide capture activity, including non-default
          inputs. When attribution is unavailable, it uses the default input.
        </p>

        <h2>Music did not resume</h2>
        <p>
          Mic Pause resumes only when it initiated the pause. It intentionally
          respects music you paused yourself. Also confirm that Resume
          automatically is enabled in Settings.
        </p>

        <h2>Meeting Assist did not mute or lower the call</h2>
        <p>
          Enable Meeting Assist, then allow Mic Pause in System Settings →
          Privacy &amp; Security → Accessibility. Automatic microphone control
          supports Teams, Zoom, FaceTime, and Phone. Mic Pause will not send a
          blind keyboard shortcut if it cannot verify the current Mute or Unmute
          control. Some fixed-volume hardware and virtual output devices do not
          expose software volume control; Settings reports that limitation.
        </p>
        <p>
          Mic Pause mutes promptly when dictation begins, then waits for the
          selected Music &amp; Meeting Recovery Delay before unmuting and
          restoring reduced sound. Optional feedback tones are off by default;
          enable them in Settings if you want audible confirmation. An unmute
          tone may be heard by meeting participants.
        </p>

        <h2>An iPhone call in Phone is not detected</h2>
        <p>
          Continuity call audio may bypass the public capture metadata available
          to Mic Pause. Keep Detect active Phone calls enabled and grant
          Accessibility permission. Mic Pause then looks for an enabled Hang Up
          control in Phone or FaceTime. If macOS does not expose that control for
          the current call route, it remains a known platform limitation.
        </p>

        <h2>Contact</h2>
        <p>
          Include your macOS version, Mic Pause version, microphone model, and a
          short description of what happened.
        </p>
        <p>
          Email{" "}
          <a href="mailto:dparadis466@gmail.com">
            dparadis466@gmail.com
          </a>
        </p>

        <h2>Privacy</h2>
        <p>
          Mic Pause does not record or transmit audio. Read the complete{" "}
          <Link href="/privacy">privacy policy</Link>.
        </p>
      </article>
    </main>
  );
}
