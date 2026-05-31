interface BentoCell {
  title: string;
  body: string;
  span: string;
  bg: string;
  textColor: string;
  bodyColor: string;
  accentEl?: React.ReactNode;
}

function AgentDecoration() {
  return (
    <div className="mt-auto pt-8 flex flex-col gap-2" aria-hidden="true">
      {[
        { proj: 'perch', state: 'EDITING FILE', detail: 'NotchShellView.swift', color: '#f97316' },
        { proj: 'portfolio-site', state: 'IDLE', detail: '', color: '#6b7280' },
        { proj: 'api-server', state: 'RUNNING COMMAND', detail: 'npm run build', color: '#f97316' },
      ].map((row) => (
        <div
          key={row.proj}
          className="flex items-center gap-3 rounded-lg px-3 py-2"
          style={{ background: 'rgba(0,0,0,0.04)' }}
        >
          <span className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ background: row.color }} />
          <span className="text-xs font-semibold text-zinc-700 flex-shrink-0" style={{ minWidth: 100 }}>
            {row.proj}
          </span>
          {row.state !== 'IDLE' && (
            <span className="text-[10px] font-medium text-zinc-400 truncate" style={{ fontFamily: 'monospace', letterSpacing: '0.04em' }}>
              {row.state} &middot; {row.detail}
            </span>
          )}
        </div>
      ))}
    </div>
  );
}

function ScheduledDecoration() {
  return (
    <div className="mt-auto pt-6 flex flex-col gap-2" aria-hidden="true">
      {[
        { name: 'Daily email summary', time: 'Daily at 09:00', active: true },
        { name: 'AAPL price alert', time: 'Every 30 min', active: true },
        { name: 'Backup check', time: 'Every 6 hours', active: false },
      ].map((t) => (
        <div key={t.name} className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <span className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ background: t.active ? '#8B7CF6' : 'rgba(255,255,255,0.2)' }} />
            <span className="text-xs font-medium" style={{ color: '#ede9fe' }}>{t.name}</span>
          </div>
          <span className="text-[10px]" style={{ color: 'rgba(255,255,255,0.35)', fontFamily: 'monospace' }}>{t.time}</span>
        </div>
      ))}
    </div>
  );
}

function StatsDecoration() {
  const bars = [42, 68, 55, 80, 62, 75, 58];
  return (
    <div className="mt-auto pt-6 flex items-end gap-1.5" aria-hidden="true">
      {bars.map((h, i) => (
        <div
          key={i}
          className="flex-1 rounded-sm"
          style={{ height: `${h * 0.6}px`, background: i === 3 ? '#8B7CF6' : 'rgba(139,124,246,0.18)' }}
        />
      ))}
    </div>
  );
}

const CELLS: BentoCell[] = [
  {
    title: 'Agent Monitor',
    body: 'Every Claude Code session, live. Project name, current tool, last prompt — without switching windows.',
    span: 'md:col-span-7',
    bg: '#ffffff',
    textColor: '#0a0a0a',
    bodyColor: '#71717a',
    accentEl: <AgentDecoration />,
  },
  {
    title: 'Chat that acts',
    body: 'Type in the notch. Bash commands, web search, file access. Connect Gmail, GitHub, and Calendar — it uses those too.',
    span: 'md:col-span-5',
    bg: '#0a0a0a',
    textColor: '#ffffff',
    bodyColor: '#52525b',
  },
  {
    title: 'Scheduled tasks',
    body: 'Conditional alerts only fire when Claude decides the condition is true. No spam, only signal.',
    span: 'md:col-span-5',
    bg: '#5b21b6',
    textColor: '#ffffff',
    bodyColor: 'rgba(255,255,255,0.5)',
    accentEl: <ScheduledDecoration />,
  },
  {
    title: 'Ambient stats',
    body: 'CPU, RAM, network, disk — on arc gauges and sparklines. Pin up to three widgets to the home view.',
    span: 'md:col-span-7',
    bg: '#f4f4f5',
    textColor: '#0a0a0a',
    bodyColor: '#71717a',
    accentEl: <StatsDecoration />,
  },
];

function BentoCard({ cell }: { cell: BentoCell }) {
  return (
    <div
      className={`${cell.span} col-span-12 flex flex-col rounded-2xl p-8 min-h-[280px]`}
      style={{ background: cell.bg }}
    >
      <h3
        className="m-0 leading-tight"
        style={{
          fontFamily: "'Geist Mono', ui-monospace, monospace",
          fontWeight: 600,
          fontSize: 'clamp(18px, 1.8vw, 24px)',
          color: cell.textColor,
          letterSpacing: '-0.03em',
          textWrap: 'balance',
        } as React.CSSProperties}
      >
        {cell.title}
      </h3>

      <p
        className="mt-3 text-sm leading-relaxed m-0"
        style={{ color: cell.bodyColor, maxWidth: 340 }}
      >
        {cell.body}
      </p>

      {cell.accentEl}
    </div>
  );
}

export default function Features() {
  return (
    <section id="features" className="bg-white">
      <div className="max-w-[1280px] mx-auto px-8 py-24 md:py-32">
        <div className="mb-10">
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
        </div>

        <div className="grid grid-cols-12 gap-3">
          {CELLS.map((cell) => (
            <BentoCard key={cell.title} cell={cell} />
          ))}
        </div>
      </div>
    </section>
  );
}
