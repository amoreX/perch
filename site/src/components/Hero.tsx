import { useRef, useEffect } from 'react';
import Button from './Button';

function AppleIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98l-.09.06c-.22.15-2.19 1.3-2.17 3.88.03 3.08 2.71 4.12 2.75 4.13-.05.13-.42 1.45-1.33 2.56M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

/**
 * Stop-motion video hero — using requestVideoFrameCallback.
 *
 * WHY this approach instead of currentTime/fastSeek:
 *   Seeking (even with fastSeek) forces the browser to decode from the nearest
 *   keyframe every call, causing stalls. requestVideoFrameCallback lets the
 *   video play at full speed through the browser's native decode pipeline
 *   (hardware-accelerated, no stalls). We simply choose to paint every 8th
 *   frame to a canvas — giving the choppy stop-motion look with zero lag.
 *
 * Pre-caching:
 *   The video is fetched as a blob on mount so the entire file is in memory
 *   before playback starts. This eliminates mid-loop buffering stalls.
 *
 * Fallback:
 *   Browsers without requestVideoFrameCallback (rare — Firefox < 130, older
 *   Safari) fall back to the video element displayed directly.
 */

const STOP_MOTION_SKIP = 8; // paint every 8th frame → ~7.5 fps from 60fps source

type rVFC = (
  now: DOMHighResTimeStamp,
  metadata: { presentedFrames: number },
) => void;

declare global {
  interface HTMLVideoElement {
    requestVideoFrameCallback(cb: rVFC): number;
    cancelVideoFrameCallback(id: number): void;
  }
}

export default function Hero() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const videoRef  = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const video  = videoRef.current;
    const canvas = canvasRef.current;
    if (!video || !canvas) return;

    let blobUrl = '';
    let rVFCId  = 0;

    // ── 1. Blob-preload so the whole file is in memory ──────────────────────
    fetch('/hero.mp4')
      .then((r) => r.blob())
      .then((blob) => {
        blobUrl    = URL.createObjectURL(blob);
        video.src  = blobUrl;
        video.load();
      });

    // ── 2. Canvas sizing — match window so CSS object-cover math is trivial ─
    const resize = () => {
      canvas.width  = window.innerWidth;
      canvas.height = window.innerHeight;
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(document.documentElement);

    // ── 3. Cover-crop drawImage helper ───────────────────────────────────────
    const ctx = canvas.getContext('2d', { alpha: false });

    const drawFrame = () => {
      if (!ctx || !video.videoWidth) return;
      const vw = video.videoWidth, vh = video.videoHeight;
      const cw = canvas.width,     ch = canvas.height;
      const videoAR  = vw / vh;
      const canvasAR = cw / ch;
      let sx = 0, sy = 0, sw = vw, sh = vh;
      if (videoAR > canvasAR) {
        sw = Math.round(vh * canvasAR);
        sx = Math.round((vw - sw) / 2);
      } else {
        sh = Math.round(vw / canvasAR);
        sy = Math.round((vh - sh) / 2);
      }
      ctx.drawImage(video, sx, sy, sw, sh, 0, 0, cw, ch);
    };

    // ── 4. rVFC loop — paint every 8th presented frame ──────────────────────
    const hasRVFC = 'requestVideoFrameCallback' in HTMLVideoElement.prototype;

    const onFrame: rVFC = (_now, meta) => {
      if (meta.presentedFrames % STOP_MOTION_SKIP === 0) drawFrame();
      rVFCId = video.requestVideoFrameCallback(onFrame);
    };

    const start = () => {
      video.play().catch(() => {/* autoplay blocked */});

      if (hasRVFC) {
        rVFCId = video.requestVideoFrameCallback(onFrame);
      }
      // Fallback: video plays normally (smooth, not stop-motion), canvas hidden
      if (!hasRVFC) {
        canvas.style.display = 'none';
        video.style.display  = 'block';
      }
    };

    video.addEventListener('canplay', start, { once: true });

    return () => {
      if (rVFCId) video.cancelVideoFrameCallback(rVFCId);
      ro.disconnect();
      video.pause();
      if (blobUrl) URL.revokeObjectURL(blobUrl);
    };
  }, []);

  return (
    <section id="home" className="relative w-full overflow-hidden" style={{ height: '100dvh' }}>
      {/* Hidden video — plays at full speed for smooth decode */}
      <video
        ref={videoRef}
        muted
        loop
        playsInline
        preload="auto"
        aria-hidden="true"
        style={{ display: 'none', position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }}
      />

      {/* Canvas — receives frames at stop-motion rate, with grayscale + dim */}
      <canvas
        ref={canvasRef}
        aria-hidden="true"
        style={{
          position: 'absolute',
          inset: 0,
          width: '100%',
          height: '100%',
          filter: 'saturate(0) brightness(1) contrast(0.9)',
        }}
      />

      {/* Purple tint overlay */}
      <div
        aria-hidden="true"
        style={{
          position: 'absolute',
          inset: 0,
          background: 'rgba(107, 88, 228, 0.7)',
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
            <Button href="#download" size="md">
              <AppleIcon />
              Download now
            </Button>
          </div>
        </div>
      </div>
    </section>
  );
}
