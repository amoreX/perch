interface FeatureItem {
  title: string;
  body: string;
}

const FEATURES: FeatureItem[] = [
  {
    title: 'Agent Monitor',
    body: 'Every Claude Code session, live. Project name, current tool, last prompt — without switching windows.',
  },
  {
    title: 'Chat that acts',
    body: 'Type in the notch. Bash commands, web search, file access. Connect Gmail, GitHub, and Calendar — it uses those too.',
  },
  {
    title: 'Scheduled tasks',
    body: 'Conditional alerts only fire when Claude decides the condition is true. No spam, only signal.',
  },
  {
    title: 'Ambient stats',
    body: 'CPU, RAM, network, disk — on arc gauges and sparklines. Pin up to three widgets to the home view.',
  },
];

function FeatureRow({ feature }: { feature: FeatureItem }) {
  return (
    <article className="py-7">
      <h3
        className="m-0 leading-tight text-zinc-950"
        style={{
          fontFamily: "'Geist Mono', ui-monospace, monospace",
          fontWeight: 600,
          fontSize: 'clamp(18px, 1.8vw, 24px)',
          letterSpacing: '-0.04em',
          textWrap: 'balance',
        } as React.CSSProperties}
      >
        {feature.title}
      </h3>
      <p
        className="mb-0 mt-3 text-zinc-500"
        style={{ maxWidth: 560, fontSize: 15, lineHeight: 1.7 }}
      >
        {feature.body}
      </p>
    </article>
  );
}

export default function Features() {
  return (
    <section id="features" className="bg-white">
      <div className="max-w-[1280px] mx-auto px-8 py-24 md:py-32">
        <div className="mb-10 max-w-2xl">
          <h2
            className="text-3xl md:text-[2.6rem] m-0 leading-[1.1]"
            style={{
              fontFamily: "'Steps Mono', monospace",
              fontWeight: 400,
              letterSpacing: '0.01em',
              color: '#0a0a0a',
              textWrap: 'balance',
            } as React.CSSProperties}
          >
            One hover does a lot.
          </h2>
          <p
            className="mb-0 mt-5 text-zinc-500"
            style={{ maxWidth: 560, fontSize: 16, lineHeight: 1.75 }}
          >
            Perch keeps the useful stuff close, without turning your desktop into another dashboard.
          </p>
        </div>

        <div className="grid gap-x-12 md:grid-cols-2">
          {FEATURES.map((feature) => (
            <FeatureRow key={feature.title} feature={feature} />
          ))}
        </div>
      </div>
    </section>
  );
}
