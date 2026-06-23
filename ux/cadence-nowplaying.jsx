// cadence-nowplaying.jsx — Full Now Playing screen for Cadence

// ─── Atmospheric background ───────────────────────────────────────────────────

function NowPlayingBackground({ colors, dark }) {
  const [displayColors, setDisplayColors] = React.useState(colors);
  const [blobOpacity, setBlobOpacity] = React.useState(1);
  const lastKey = React.useRef(colors.join(','));

  React.useEffect(() => {
    const key = colors.join(',');
    if (key === lastKey.current) return;
    setBlobOpacity(0);
    const t = setTimeout(() => {
      setDisplayColors([...colors]);
      lastKey.current = key;
      setBlobOpacity(1);
    }, 480);
    return () => clearTimeout(t);
  }, [colors.join(',')]);

  const c = displayColors;
  const overlay = dark ? 'rgba(20,20,23,0.60)' : 'rgba(244,244,248,0.74)';

  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', zIndex: 0, pointerEvents: 'none' }}>
      <div style={{ position: 'absolute', inset: 0, opacity: blobOpacity, transition: 'opacity 0.5s ease' }}>
        <div style={{
          position: 'absolute', width: '70%', height: '70%', top: '-18%', left: '-12%',
          borderRadius: '50%',
          background: `radial-gradient(circle, ${c[0]}c8 0%, transparent 68%)`,
          filter: 'blur(68px)',
        }} />
        <div style={{
          position: 'absolute', width: '58%', height: '58%', bottom: '-14%', right: '-8%',
          borderRadius: '50%',
          background: `radial-gradient(circle, ${c[1]}a8 0%, transparent 68%)`,
          filter: 'blur(84px)',
        }} />
        <div style={{
          position: 'absolute', width: '48%', height: '48%', top: '28%', left: '22%',
          borderRadius: '50%',
          background: `radial-gradient(circle, ${c[2] || c[0]}88 0%, transparent 68%)`,
          filter: 'blur(96px)',
        }} />
      </div>
      <div style={{ position: 'absolute', inset: 0, background: overlay, transition: 'background 0.6s ease' }} />
    </div>
  );
}

// ─── Cover art ────────────────────────────────────────────────────────────────

function NowPlayingCover({ colors, size, isPlaying }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: 14, overflow: 'hidden', flexShrink: 0,
      background: `linear-gradient(140deg, ${colors[0]} 0%, ${colors[1]} 52%, ${colors[2]} 100%)`,
      boxShadow: `0 18px 60px ${colors[1]}58, 0 4px 18px rgba(0,0,0,0.28)`,
      position: 'relative',
      animation: isPlaying ? 'npBreathe 3.5s ease-in-out infinite' : 'none',
    }}>
      {/* Vinyl disc */}
      <div style={{
        position: 'absolute', top: '50%', left: '50%',
        transform: 'translate(-50%,-50%)',
        width: size * 0.27, height: size * 0.27, borderRadius: '50%',
        background: 'rgba(0,0,0,0.15)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <div style={{
          width: size * 0.108, height: size * 0.108, borderRadius: '50%',
          background: 'rgba(0,0,0,0.24)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <div style={{ width: size * 0.04, height: size * 0.04, borderRadius: '50%', background: 'rgba(255,255,255,0.22)' }} />
        </div>
      </div>
      {/* Highlight */}
      <div style={{
        position: 'absolute', top: '5%', left: '4%',
        width: '28%', height: '18%', borderRadius: '50%',
        background: 'rgba(255,255,255,0.09)',
      }} />
    </div>
  );
}

// ─── Seek bar ─────────────────────────────────────────────────────────────────

function NPSeekBar({ progress, duration, dark, onSeek }) {
  const [hover, setHover] = React.useState(false);
  const [dragging, setDragging] = React.useState(false);
  const trackRef = React.useRef(null);

  const accent = dark ? '#0A84FF' : '#007AFF';
  const trackBg = dark ? 'rgba(255,255,255,0.18)' : 'rgba(0,0,0,0.13)';
  const timeColor = dark ? 'rgba(255,255,255,0.40)' : 'rgba(0,0,0,0.36)';
  const pct = duration > 0 ? Math.min(100, (progress / duration) * 100) : 0;
  const active = hover || dragging;

  const fmt = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;

  const seekTo = (e) => {
    const rect = trackRef.current.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    onSeek(Math.floor(ratio * duration));
  };

  React.useEffect(() => {
    if (!dragging) return;
    const onMove = (e) => seekTo(e);
    const onUp = () => setDragging(false);
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
    return () => { window.removeEventListener('mousemove', onMove); window.removeEventListener('mouseup', onUp); };
  }, [dragging, duration]);

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, width: '100%' }}>
      <span style={{ fontSize: 11, fontWeight: 500, color: timeColor, minWidth: 34, textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>
        {fmt(progress)}
      </span>
      <div
        ref={trackRef}
        onMouseEnter={() => setHover(true)}
        onMouseLeave={() => { if (!dragging) setHover(false); }}
        onMouseDown={(e) => { setDragging(true); setHover(true); seekTo(e); }}
        style={{ flex: 1, height: 20, display: 'flex', alignItems: 'center', cursor: 'pointer' }}
      >
        <div style={{ width: '100%', height: active ? 5 : 3, borderRadius: 3, background: trackBg, position: 'relative', transition: 'height 0.12s ease' }}>
          <div style={{ height: '100%', borderRadius: 3, background: accent, width: `${pct}%`, position: 'relative', transition: dragging ? 'none' : 'width 0.5s linear' }}>
            {active && (
              <div style={{ position: 'absolute', right: -7, top: '50%', transform: 'translateY(-50%)', width: 14, height: 14, borderRadius: '50%', background: accent, boxShadow: '0 1px 6px rgba(0,0,0,0.32)' }} />
            )}
          </div>
        </div>
      </div>
      <span style={{ fontSize: 11, fontWeight: 500, color: timeColor, minWidth: 34, fontVariantNumeric: 'tabular-nums' }}>
        {fmt(duration)}
      </span>
    </div>
  );
}

// ─── Buttons ──────────────────────────────────────────────────────────────────

function NPIconBtn({ children, onClick, active, dark, size = 44 }) {
  const [hover, setHover] = React.useState(false);
  const accent = dark ? '#0A84FF' : '#007AFF';
  const ic = dark ? 'rgba(255,255,255,0.70)' : 'rgba(0,0,0,0.60)';
  const hbg = dark ? 'rgba(255,255,255,0.11)' : 'rgba(0,0,0,0.07)';
  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        width: size, height: size, borderRadius: '50%', flexShrink: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        cursor: 'pointer', position: 'relative',
        color: active ? accent : ic,
        background: hover ? hbg : 'transparent',
        transition: 'color 0.12s, background 0.12s, transform 0.1s',
        transform: hover ? 'scale(1.09)' : 'scale(1)',
      }}
    >
      {children}
      {active && (
        <div style={{ position: 'absolute', bottom: 3, left: '50%', transform: 'translateX(-50%)', width: 3, height: 3, borderRadius: '50%', background: accent }} />
      )}
    </div>
  );
}

function NPTransBtn({ children, onClick, dark, big }) {
  const [hover, setHover] = React.useState(false);
  const textColor = dark ? 'rgba(255,255,255,0.92)' : 'rgba(0,0,0,0.88)';
  const ic = dark ? 'rgba(255,255,255,0.76)' : 'rgba(0,0,0,0.66)';
  const size = big ? 72 : 48;

  if (big) return (
    <div onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)} style={{
      width: size, height: size, borderRadius: '50%', flexShrink: 0,
      background: textColor, display: 'flex', alignItems: 'center', justifyContent: 'center',
      cursor: 'pointer',
      boxShadow: dark ? '0 4px 22px rgba(0,0,0,0.52)' : '0 4px 22px rgba(0,0,0,0.16)',
      transform: hover ? 'scale(1.06)' : 'scale(1)',
      transition: 'transform 0.1s, box-shadow 0.12s',
    }}>{children}</div>
  );

  return (
    <div onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)} style={{
      width: size, height: size, borderRadius: '50%', flexShrink: 0,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      cursor: 'pointer', color: ic,
      transform: hover ? 'scale(1.09)' : 'scale(1)',
      transition: 'transform 0.1s',
    }}>{children}</div>
  );
}

// ─── Action pill ──────────────────────────────────────────────────────────────

function NPActionPill({ icon, label, onClick, dark, borderColor, textColor }) {
  const [hover, setHover] = React.useState(false);
  return (
    <button onClick={onClick} onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)} style={{
      display: 'flex', alignItems: 'center', gap: 5,
      padding: '5px 13px', borderRadius: 7,
      border: `0.5px solid ${borderColor}`,
      background: hover ? (dark ? 'rgba(255,255,255,0.13)' : 'rgba(0,0,0,0.08)') : (dark ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.04)'),
      cursor: 'pointer', color: textColor, fontSize: 12, fontWeight: 500,
      fontFamily: 'inherit', transition: 'background 0.12s',
    }}>
      {icon}{label}
    </button>
  );
}

// ─── Up Next row ──────────────────────────────────────────────────────────────

function UpNextRow({ track, index, dark, onDoubleClick }) {
  const [hover, setHover] = React.useState(false);
  const textColor = dark ? 'rgba(255,255,255,0.84)' : 'rgba(0,0,0,0.80)';
  const sub = dark ? 'rgba(255,255,255,0.44)' : 'rgba(0,0,0,0.40)';
  const hbg = dark ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.05)';
  const fmt = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;

  return (
    <div
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onDoubleClick={onDoubleClick}
      style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '7px 12px', borderRadius: 7,
        background: hover ? hbg : 'transparent',
        transition: 'background 0.10s', cursor: 'default',
      }}
    >
      <span style={{ width: 18, flexShrink: 0, textAlign: 'center', fontSize: 12, color: sub, fontVariantNumeric: 'tabular-nums', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        {hover ? <IconPlay size={9} color={textColor} /> : index}
      </span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, fontWeight: 400, color: textColor, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', lineHeight: '17px' }}>{track.title}</div>
        {track.artist && (
          <div style={{ fontSize: 11, color: sub, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', lineHeight: '15px' }}>{track.artist}</div>
        )}
      </div>
      <span style={{ fontSize: 12, color: sub, fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>{fmt(track.duration)}</span>
    </div>
  );
}

// ─── Spectrum Visualizer ────────────────────────────────────────────────────

function SpectrumVisualizer({ isPlaying, dark, accent }) {
  const canvasRef = React.useRef(null);
  const isPlayingRef = React.useRef(isPlaying);
  const animRef = React.useRef(null);
  const barsRef = React.useRef(
    Array.from({ length: 10 }, () => ({ cur: 0.05, tgt: 0.05, peak: 0.05, peakHold: 0 }))
  );
  const lastTickRef = React.useRef(0);

  React.useEffect(() => { isPlayingRef.current = isPlaying; }, [isPlaying]);

  React.useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const BANDS = ['32', '64', '125', '250', '500', '1K', '2K', '4K', '8K', '16K'];
    // Rock preset normalized bias (0–1)
    const BIAS = [6, 5, 3, 0, -2, -3, -2, 1, 4, 5].map(v => (v + 12) / 24);

    const frame = (ts) => {
      animRef.current = requestAnimationFrame(frame);
      const playing = isPlayingRef.current;
      const dpr = window.devicePixelRatio || 1;
      const W = canvas.width / dpr;
      const H = canvas.height / dpr;

      // New targets every ~150ms when playing
      if (playing && ts - lastTickRef.current > 150) {
        lastTickRef.current = ts;
        barsRef.current.forEach((b, i) => {
          const lo = 0.08 + BIAS[i] * 0.12;
          const hi = 0.28 + BIAS[i] * 0.60;
          b.tgt = lo + Math.random() * (hi - lo);
        });
      }

      // Interpolate current → target
      barsRef.current.forEach(b => {
        b.cur += (b.tgt - b.cur) * (playing ? 0.18 : 0.06);
        if (!playing) b.tgt = Math.max(0.04, b.tgt * 0.986);
        // Peak hold & decay
        if (b.cur >= b.peak) { b.peak = b.cur; b.peakHold = 52; }
        else if (b.peakHold > 0) { b.peakHold--; }
        else { b.peak = Math.max(b.cur, b.peak - 0.005); }
      });

      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.save();
      ctx.scale(dpr, dpr);

      const labelH = 16;
      const plotH = H - labelH - 4;
      const n = 10;
      const gap = 3;
      const bw = (W - gap * (n - 1)) / n;

      barsRef.current.forEach((b, i) => {
        const x = i * (bw + gap);
        const bh = Math.max(2, b.cur * plotH);
        const y = plotH - bh + 2;

        // Bar gradient
        const g = ctx.createLinearGradient(0, y, 0, plotH + 2);
        g.addColorStop(0, accent + 'f0');
        g.addColorStop(1, accent + '40');
        ctx.fillStyle = g;
        ctx.beginPath();
        if (ctx.roundRect) ctx.roundRect(x, y, bw, bh, [2, 2, 1, 1]);
        else ctx.rect(x, y, bw, bh);
        ctx.fill();

        // Peak line
        if (b.peak > 0.1) {
          const py = plotH - b.peak * plotH + 2;
          ctx.fillStyle = accent + 'cc';
          ctx.fillRect(x, py - 1.5, bw, 1.5);
        }

        // Frequency label
        ctx.fillStyle = dark ? 'rgba(255,255,255,0.28)' : 'rgba(0,0,0,0.28)';
        ctx.font = '9px -apple-system, "SF Pro Text", sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(BANDS[i], x + bw / 2, H - 2);
      });

      ctx.restore();
    };

    animRef.current = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(animRef.current);
  }, [dark, accent]);

  const DPR = (typeof window !== 'undefined' && window.devicePixelRatio) || 1;
  return (
    <canvas
      ref={canvasRef}
      width={Math.round(214 * DPR)}
      height={Math.round(110 * DPR)}
      style={{ width: '100%', height: 110, display: 'block' }}
    />
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

function NowPlayingScreen({ dark, isPlaying, onPlayPause, shuffleOn, repeatOn, onShuffleToggle, onRepeatToggle, playingAlbum, playingTrackIdx, onNext, onPrev, onPlayTrack, onGoToAlbum }) {
  const [progress, setProgress] = React.useState(0);
  const [isFav, setIsFav] = React.useState(false);
  const containerRef = React.useRef(null);
  const [containerW, setContainerW] = React.useState(880);

  const album = playingAlbum || ALBUM_DATA[2];
  const tracks = getAlbumTracks(album);
  const safeIdx = Math.min(playingTrackIdx, tracks.length - 1);
  const currentTrack = tracks[safeIdx] || tracks[0];
  const duration = currentTrack?.duration || 234;

  // Build Up Next list (next 5 after current)
  const upNext = Array.from({ length: 5 }, (_, i) => {
    const idx = (safeIdx + 1 + i) % tracks.length;
    return { ...tracks[idx], artist: album.artist, _idx: idx };
  });

  // Reset progress when track changes
  React.useEffect(() => { setProgress(0); }, [album.id, safeIdx]);

  // Playback timer
  React.useEffect(() => {
    if (!isPlaying) return;
    const id = setInterval(() => setProgress(p => (p >= duration - 1 ? 0 : p + 1)), 1000);
    return () => clearInterval(id);
  }, [isPlaying, duration, album.id, safeIdx]);

  // Responsive width
  React.useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const ro = new ResizeObserver(es => setContainerW(es[0].contentRect.width));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const wide = containerW >= 800;
  const colors = album.colors;
  const accent = dark ? '#0A84FF' : '#007AFF';
  const textColor = dark ? 'rgba(255,255,255,0.92)' : 'rgba(0,0,0,0.88)';
  const subColor = dark ? 'rgba(255,255,255,0.50)' : 'rgba(0,0,0,0.46)';
  const mutedColor = dark ? 'rgba(255,255,255,0.30)' : 'rgba(0,0,0,0.28)';
  const borderColor = dark ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.08)';
  const playIconColor = dark ? '#1c1c1e' : '#ffffff';

  const coverSize = wide ? Math.min(300, Math.floor(containerW * 0.28)) : Math.min(220, Math.floor(containerW * 0.55));
  const controlMaxW = Math.max(coverSize + 48, 340);
  const meta = getAlbumMeta(album);

  return (
    <div ref={containerRef} style={{ flex: 1, position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: wide ? 'row' : 'column' }}>
      <NowPlayingBackground colors={colors} dark={dark} />

      {/* LEFT — cover + controls */}
      <div style={{
        flex: 1, position: 'relative', zIndex: 1, minWidth: 0,
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        padding: wide ? '40px 48px' : '28px 24px',
        gap: 22, overflowY: 'auto',
      }}>
        <NowPlayingCover colors={colors} size={coverSize} isPlaying={isPlaying} />

        {/* Track info */}
        <div style={{ textAlign: 'center', width: '100%', maxWidth: controlMaxW }}>
          <div style={{ fontSize: 26, fontWeight: 700, letterSpacing: '-0.025em', color: textColor, lineHeight: 1.2, marginBottom: 5, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {currentTrack?.title || '—'}
          </div>
          <div style={{ fontSize: 15, fontWeight: 500, color: accent, lineHeight: 1.3, marginBottom: 3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {album.artist}
          </div>
          <div style={{ fontSize: 13, color: subColor, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {album.title}
          </div>
        </div>

        {/* Seek bar */}
        <div style={{ width: '100%', maxWidth: controlMaxW }}>
          <NPSeekBar progress={progress} duration={duration} dark={dark} onSeek={setProgress} />
        </div>

        {/* Transport */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          <NPIconBtn dark={dark} active={shuffleOn} onClick={onShuffleToggle} size={44}>
            <IconShuffle size={22} />
          </NPIconBtn>
          <NPTransBtn dark={dark} onClick={onPrev}>
            <IconPrevious size={26} />
          </NPTransBtn>
          <NPTransBtn dark={dark} big onClick={onPlayPause}>
            {isPlaying ? <IconPause size={26} color={playIconColor} /> : <IconPlay size={26} color={playIconColor} />}
          </NPTransBtn>
          <NPTransBtn dark={dark} onClick={onNext}>
            <IconNext size={26} />
          </NPTransBtn>
          <NPIconBtn dark={dark} active={repeatOn} onClick={onRepeatToggle} size={44}>
            <IconRepeat size={22} />
          </NPIconBtn>
        </div>

        {/* Actions */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div
            onClick={() => setIsFav(f => !f)}
            style={{ width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', transition: 'transform 0.15s' }}
            onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.18)'}
            onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
          >
            <IconHeart size={22} color={isFav ? '#FF375F' : mutedColor} filled={isFav} />
          </div>
          <NPActionPill icon={<IconAlbum size={12} />} label="К альбому" onClick={onGoToAlbum} dark={dark} borderColor={borderColor} textColor={textColor} />
          <NPActionPill icon={<IconArtist size={12} />} label="К артисту" dark={dark} borderColor={borderColor} textColor={textColor} />
        </div>
      </div>

      {/* RIGHT — Up Next + Spectrum (wide) */}
      {wide && (
        <div style={{
          width: 262, flexShrink: 0, position: 'relative', zIndex: 1,
          borderLeft: `0.5px solid ${borderColor}`,
          display: 'flex', flexDirection: 'column', overflow: 'hidden',
        }}>
          {/* Up Next — scrollable, fills available space */}
          <div style={{ flex: 1, overflowY: 'auto', padding: '24px 12px 10px' }}>
            <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.06em', color: mutedColor, textTransform: 'uppercase', padding: '0 12px', marginBottom: 8 }}>
              Далее в очереди
            </div>
            {upNext.map((track, i) => (
              <UpNextRow key={i} track={track} index={track.index} dark={dark} onDoubleClick={() => onPlayTrack && onPlayTrack(track._idx)} />
            ))}
          </div>

          {/* Spectrum Visualizer — pinned to bottom */}
          <div style={{ flexShrink: 0, borderTop: `0.5px solid ${borderColor}`, padding: '14px 20px 16px' }}>
            <SpectrumVisualizer isPlaying={isPlaying} dark={dark} accent={accent} />
          </div>
        </div>
      )}

      {/* BOTTOM — Up Next (narrow) */}
      {!wide && (
        <div style={{
          position: 'relative', zIndex: 1,
          borderTop: `0.5px solid ${borderColor}`,
          padding: '14px 12px 18px',
          background: dark ? 'rgba(0,0,0,0.15)' : 'rgba(255,255,255,0.15)',
        }}>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.06em', color: mutedColor, textTransform: 'uppercase', padding: '0 12px', marginBottom: 6 }}>
            Далее
          </div>
          {upNext.slice(0, 3).map((track, i) => (
            <UpNextRow key={i} track={track} index={track.index} dark={dark} />
          ))}
        </div>
      )}
    </div>
  );
}

Object.assign(window, { NowPlayingScreen });
