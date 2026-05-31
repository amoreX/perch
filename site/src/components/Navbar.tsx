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

export default function Navbar() {
  return (
    <header
      className="fixed flex  w-full top-0 left-0 right-0 z-50"
      // style={{ background: '#111111' }}
    >
      <div className='bg-[#111111] z-0 absolute h-[10px] w-full'  ></div>
      <div className='bg-[#111111] z-0 absolute h-full w-[220px] rounded-br-[26px]' ></div>
      <div className='bg-[#111111] z-0 absolute h-full w-[268px] right-0 rounded-bl-[26px]' ></div>
      <div className='bg-[#111111] left-1/2 -translate-x-[59%]  z-0 absolute h-full w-[280px] rounded-b-[26px]' ></div>
      <div className="max-w-[1280px] w-full z-20 mx-auto px-8">
        <nav className="flex items-center h-14">
          {/* Steps Mono wordmark */}
          <a
            href="/"
            className="no-underline flex-shrink-0"
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

          {/* Center nav links */}
          <div className="flex-1 flex justify-center items-center gap-0.5">
            {NAV_LINKS.map((link) => (
              <a
                key={link.label}
                href={link.href}
                className="h-10 px-3.5 flex items-center rounded-full text-sm no-underline text-white/45 hover:text-white/85"
                style={{ letterSpacing: '-0.02em', fontFamily: "'Geist Mono', monospace" }}
              >
                {link.label}
              </a>
            ))}
          </div>

          <Button href="#download" size="sm">
            <AppleIcon />
            Download
          </Button>
        </nav>
      </div>
    </header>
  );
}
