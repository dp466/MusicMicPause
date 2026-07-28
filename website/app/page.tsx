import Image from "next/image";
import Link from "next/link";

const features = [
  {
    number: "01",
    title: "Pauses at the right moment",
    body: "Mic Pause watches the active state of your current microphone and pauses Apple Music when a call, recording, or voice chat begins.",
  },
  {
    number: "02",
    title: "Resumes on your terms",
    body: "Choose an immediate, 1-, 2-, or 5-second delay. Music only resumes when Mic Pause initiated the pause.",
  },
  {
    number: "03",
    title: "Private by construction",
    body: "No audio stream is opened. There is no recording, analysis, account, advertising, analytics, or network access.",
  },
];

export default function Home() {
  return (
    <main>
      <nav className="nav shell" aria-label="Main navigation">
        <Link className="brand" href="/">
          <Image src="/app-icon.png" alt="" width={42} height={42} priority />
          <span>Mic Pause</span>
        </Link>
        <div className="navLinks">
          <a href="#features">Features</a>
          <Link href="/privacy">Privacy</Link>
          <Link href="/support">Support</Link>
        </div>
      </nav>

      <section className="hero shell">
        <div className="heroCopy">
          <p className="eyebrow">A QUIETER WAY TO WORK</p>
          <h1>Your music knows when to pause.</h1>
          <p className="lede">
            Mic Pause is a thoughtful macOS menu-bar utility that automatically
            pauses Apple Music when your microphone becomes active.
          </p>
          <div className="heroActions">
            <span className="comingSoon">Coming soon to the Mac App Store</span>
            <span className="requirement">Requires macOS 14 or later</span>
          </div>
        </div>
        <div className="heroVisual">
          <Image
            src="/screenshots/automatic-pause.jpg"
            alt="Mic Pause showing that microphone monitoring is ready"
            width={2560}
            height={1600}
            priority
          />
        </div>
      </section>

      <section className="trustStrip" aria-label="Privacy summary">
        <div className="shell trustItems">
          <span>No recording</span>
          <span>No analytics</span>
          <span>No accounts</span>
          <span>No network access</span>
        </div>
      </section>

      <section className="features shell" id="features">
        <div className="sectionIntro">
          <p className="eyebrow">BUILT TO DISAPPEAR</p>
          <h2>One less thing to think about.</h2>
          <p>
            Set it once, leave it in your menu bar, and let your calls sound
            clear without reaching for playback controls.
          </p>
        </div>
        <div className="featureGrid">
          {features.map((feature) => (
            <article className="featureCard" key={feature.number}>
              <span>{feature.number}</span>
              <h3>{feature.title}</h3>
              <p>{feature.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="showcase shell">
        <div className="showcaseCopy">
          <p className="eyebrow">YOUR PREFERENCES</p>
          <h2>Simple controls. Beautifully out of the way.</h2>
          <p>
            Choose how playback returns, launch automatically when you sign in,
            and see permission status at a glance.
          </p>
        </div>
        <Image
          src="/screenshots/playback-your-way.jpg"
          alt="Mic Pause settings for monitoring and playback"
          width={2560}
          height={1600}
        />
      </section>

      <footer className="footer shell">
        <div>
          <strong>Mic Pause</strong>
          <p>Quiet music. Clear conversations.</p>
        </div>
        <div className="footerLinks">
          <Link href="/privacy">Privacy Policy</Link>
          <Link href="/support">Support</Link>
        </div>
        <p>© 2026 Dilan Paradis</p>
      </footer>
    </main>
  );
}
