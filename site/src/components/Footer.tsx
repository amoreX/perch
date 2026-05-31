export default function Footer() {
  return (
    <footer id="contact" className="bg-white border-t border-zinc-100">
      <div className="max-w-[1280px] mx-auto px-8 pt-16 pb-10">
        <p
          className="m-0 text-zinc-900 leading-none select-none"
          style={{
            fontFamily: "'Steps Mono', monospace",
            fontWeight: 400,
            fontSize: 'clamp(64px, 13vw, 190px)',
            letterSpacing: '0.01em',
          }}
        >
          Perch
        </p>

        <div className="flex items-center justify-between pt-6 mt-6 border-t border-zinc-100">
          <p
            className="text-xs text-zinc-300 m-0"
            style={{ fontFamily: "'Geist Mono', monospace", letterSpacing: '-0.02em' }}
          >
            macOS 14+ &middot; ARM64 &amp; x86
          </p>
          <p
            className="text-xs text-zinc-300 m-0"
            style={{ fontFamily: "'Geist Mono', monospace", letterSpacing: '-0.02em' }}
          >
            Built for the notch.
          </p>
        </div>
      </div>
    </footer>
  );
}
