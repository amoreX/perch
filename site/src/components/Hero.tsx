import { useRef } from 'react';
import { motion, useMotionTemplate, useScroll, useTransform } from 'framer-motion';
import Button from './Button';

function AppleIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98l-.09.06c-.22.15-2.19 1.3-2.17 3.88.03 3.08 2.71 4.12 2.75 4.13-.05.13-.42 1.45-1.33 2.56M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

export default function Hero() {
  const sectionRef = useRef<HTMLElement>(null);
  const { scrollYProgress: mediaScrollProgress } = useScroll({
    target: sectionRef,
    offset: ['start start', 'end start'],
  });
  const { scrollYProgress: mediaBlurProgress } = useScroll({
    target: sectionRef,
    offset: ['end 400px', 'end start'],
  });
  const rawMediaY = useTransform(mediaScrollProgress, [0, 1], [0, 300]);
  const rawMediaBlur = useTransform(mediaBlurProgress, [0, 1], [0, 40]);
  const mediaFilter = useMotionTemplate`blur(${rawMediaBlur}px)`;

  return (
    <section ref={sectionRef} id="home" className="relative w-full overflow-hidden bg-[#111111]" style={{ height: '100dvh' }}>
      <motion.div
        aria-hidden="true"
        className="absolute inset-0"
        style={{ y: rawMediaY, filter: mediaFilter, height: 'calc(100% + 300px)' }}
      >
        <img
          src="/hero-image.jpg"
          alt=""
          aria-hidden="true"
          className="absolute inset-0 h-full w-full scale-150 object-cover object-center"
          style={{ filter: 'saturate(0) brightness(1) contrast(2)' }}
        />

        {/* Purple tint overlay */}
        <div
          aria-hidden="true"
          style={{
            position: 'absolute',
            inset: 0,
            background: 'rgba(107, 88, 228, 0)',
            mixBlendMode: 'overlay',
            pointerEvents: 'none',
          }}
        />

        {/* Bottom fade */}
        <div
          aria-hidden="true"
          style={{
            position: 'absolute',
            inset: '60% 0 0 0',
            background: 'linear-gradient(to bottom, transparent, rgba(0,0,0,0.3))',
            pointerEvents: 'none',
          }}
        />
      </motion.div>

      {/* Tagline — same container as navbar and all sections */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'flex-start',
          paddingTop: 'clamp(96px, 15vh, 168px)',
        }}
      >
        <div
          style={{
            width: '100%',
            maxWidth: 1280,
            margin: '0 auto',
            padding: '0 32px',
          }}
        >
          <h1
            style={{
              fontFamily: "'Steps Mono', monospace",
              fontSize: 'clamp(44px, 6vw, 82px)',
              fontWeight: 400,
              color: '#ffffff',
              lineHeight: 1.05,
              letterSpacing: '0.01em',
              margin: 0,
            }}
          >
            Perch lives
            <br />
            in your notch.
          </h1>

          {/* Download CTA */}
          <div style={{ marginTop: 64 }}>
            <Button href="#download" size="xl">
              <span className="[&_svg]:size-4">
                <AppleIcon />
              </span>
              Get Perch For Mac
            </Button>
          </div>
        </div>
      </div>
    </section>
  );
}
