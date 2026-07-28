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
          Mic Pause follows the current default input device. In System Settings
          → Sound → Input, confirm that the microphone used by your call or
          recording app is selected as the default input.
        </p>

        <h2>Music did not resume</h2>
        <p>
          Mic Pause resumes only when it initiated the pause. It intentionally
          respects music you paused yourself. Also confirm that Resume
          automatically is enabled in Settings.
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
