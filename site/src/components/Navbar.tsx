import Button from './Button';

const NAV_LINKS = [
  { label: 'Features', href: '#features' },
  { label: 'Download', href: '#download' },
  { label: 'GitHub', href: 'https://github.com/amoreX/perch' },
];

function AppleIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98l-.09.06c-.22.15-2.19 1.3-2.17 3.88.03 3.08 2.71 4.12 2.75 4.13-.05.13-.42 1.45-1.33 2.56M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

const NOTCH = '#111111';

// Aligns content with max-w-[1280px] mx-auto px-8 container at any viewport width.
// On narrow viewports the container is full-width so offset = 0 + 32px.
// On wide viewports it's (vw - 1280px) / 2 + 32px.
const CONTAINER_ALIGN = 'calc(max(0px, (100vw - 1280px) / 2) + 32px)';

export default function Navbar() {
  return (
    <header className="fixed top-0 left-0 right-0 z-50 pointer-events-none">
      {/* Full-width connecting bar */}
      <div className="absolute top-0 left-0 right-0 h-[10px] bg-[#111111] pointer-events-auto" />

      {/* Left notch — bleeds to screen left edge, only bottom-right rounded */}
      <div
        className="absolute top-0 left-0 flex items-center h-14 pointer-events-auto"
        style={{
          background: NOTCH,
          borderRadius: '0 0 28px 0',
          paddingLeft: CONTAINER_ALIGN,
          paddingRight: '16px',
        }}
      >
        <a
          href="/"
          className="no-underline"
          style={{
            fontFamily: "'Steps Mono', monospace",
            fontSize: 18,
            fontWeight: 400,
            color: '#ffffff',
            letterSpacing: '0.02em',
            lineHeight: 1,
          }}
        >
          Perch
        </a>
      </div>

      {/* Center notch — equal 8px pad (matches h-10 buttons' 8px vertical breathing room) */}
      <div
        className="absolute left-1/2 -translate-x-1/2 top-0 flex items-center h-14 px-2 gap-0.5 pointer-events-auto"
        style={{ background: NOTCH, borderRadius: '0 0 28px 28px' }}
      >
        {NAV_LINKS.map((link) => (
          <a
            key={link.label}
            href={link.href}
            className="h-10 px-3.5 flex items-center rounded-full text-sm no-underline text-white/45 hover:text-white/85 hover:bg-white/10"
            style={{ letterSpacing: '-0.02em', fontFamily: "'Geist Mono', monospace" }}
          >
            {link.label}
          </a>
        ))}
      </div>

      {/* Right notch — bleeds to screen right edge, only bottom-left rounded */}
      <div
        className="absolute top-0 right-0 flex items-center h-14 pointer-events-auto"
        style={{
          background: NOTCH,
          borderRadius: '0 0 0 28px',
          paddingRight: CONTAINER_ALIGN,
          paddingLeft: '12px',
        }}
      >
        <Button href="#download" size="sm">
          <AppleIcon />
          Download
        </Button>
      </div>
    </header>
  );
}
