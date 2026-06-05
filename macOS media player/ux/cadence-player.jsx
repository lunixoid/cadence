// cadence-player.jsx — Now Playing bar for Cadence

function NowPlayingBar({ dark, isPlaying, onPlayPause, shuffleOn, repeatOn, onShuffleToggle, onRepeatToggle, trackTitle, trackArtist, trackColors, trackDuration }) {
  const [progress, setProgress] = React.useState(67); // seconds
  const [volume, setVolume] = React.useState(72);
  const [isDragging, setIsDragging] = React.useState(false);
  const [hoverProgress, setHoverProgress] = React.useState(null);
  const duration = trackDuration || 234;

  const accent = dark ? '#0A84FF' : '#007AFF';
  const barBg = dark ? 'rgba(30,30,32,0.92)' : 'rgba(255,255,255,0.92)';
  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)';
  const textColor = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.85)';
  const subColor = dark ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.5)';
  const iconColor = dark ? 'rgba(255,255,255,0.65)' : 'rgba(0,0,0,0.55)';
  const iconHoverColor = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.85)';
  const trackBg = dark ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.1)';
  const activeIcon = accent;

  // Auto-advance progress
  React.useEffect(() => {
    if (!isPlaying) return;
    const id = setInterval(() => {
      setProgress(p => p >= duration ? 0 : p + 1);
    }, 1000);
    return () => clearInterval(id);
  }, [isPlaying, duration]);

  const formatTime = (s) => {
    const m = Math.floor(s / 60);
    const sec = Math.floor(s % 60);
    return `${m}:${sec.toString().padStart(2, '0')}`;
  };

  const handleProgressClick = (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    setProgress(Math.floor(ratio * duration));
  };

  const handleVolumeChange = (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    setVolume(Math.floor(ratio * 100));
  };

  const PlayerButton = ({ children, onClick, active, size = 28 }) => {
    const [h, setH] = React.useState(false);
    return (
      <div
        onClick={onClick}
        onMouseEnter={() => setH(true)}
        onMouseLeave={() => setH(false)}
        style={{
          width: size, height: size, borderRadius: '50%',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer', color: active ? activeIcon : (h ? iconHoverColor : iconColor),
          transition: 'color 0.12s, transform 0.1s',
          transform: h ? 'scale(1.08)' : 'scale(1)',
          position: 'relative',
        }}
      >
        {children}
        {active && (
          <div style={{
            position: 'absolute', bottom: -2, left: '50%', transform: 'translateX(-50%)',
            width: 4, height: 4, borderRadius: '50%', background: activeIcon,
          }}></div>
        )}
      </div>
    );
  };

  // Current track cover
  const coverColors = trackColors || ['#5c2d91', '#8e44ad', '#c39bd3'];
  const displayTitle = trackTitle || 'Static Dreams';
  const displayArtist = trackArtist || 'Neon Drift';

  return (
    <div style={{
      height: 72, flexShrink: 0,
      background: barBg,
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
      borderTop: `0.5px solid ${borderColor}`,
      display: 'flex', alignItems: 'center',
      padding: '0 16px', gap: 12,
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
    }}>
      {/* Left: Track info */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, width: 220, flexShrink: 0 }}>
        {/* Mini cover */}
        <div style={{
          width: 48, height: 48, borderRadius: 6, overflow: 'hidden', flexShrink: 0,
          boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
          background: `linear-gradient(135deg, ${coverColors[0]} 0%, ${coverColors[1]} 50%, ${coverColors[2]} 100%)`,
          position: 'relative',
        }}>
          {/* Vinyl hint */}
          <div style={{
            position: 'absolute', top: '50%', left: '50%',
            transform: 'translate(-50%, -50%)',
            width: 18, height: 18, borderRadius: '50%',
            background: 'rgba(0,0,0,0.15)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <div style={{ width: 7, height: 7, borderRadius: '50%', background: 'rgba(0,0,0,0.25)' }}></div>
          </div>
        </div>
        <div style={{ minWidth: 0 }}>
          <div style={{
            fontSize: 13, fontWeight: 600, color: textColor,
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            lineHeight: '17px',
          }}>{displayTitle}</div>
          <div style={{
            fontSize: 11, fontWeight: 400, color: subColor,
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            lineHeight: '15px', marginTop: 1,
          }}>{displayArtist}</div>
        </div>
        {/* Heart icon */}
        <PlayerButton size={24}>
          <IconHeart size={13} color={iconColor} />
        </PlayerButton>
      </div>

      {/* Center: Controls + Progress */}
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        alignItems: 'center', gap: 4, maxWidth: 500, margin: '0 auto',
      }}>
        {/* Playback controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          <PlayerButton active={shuffleOn} onClick={onShuffleToggle} size={26}>
            <IconShuffle size={14} />
          </PlayerButton>
          <PlayerButton size={26}>
            <IconPrevious size={14} />
          </PlayerButton>
          {/* Play/Pause — larger, filled circle */}
          <div
            onClick={onPlayPause}
            style={{
              width: 34, height: 34, borderRadius: '50%',
              background: textColor,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer', transition: 'transform 0.1s',
            }}
            onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.07)'}
            onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
          >
            {isPlaying
              ? <IconPause size={14} color={dark ? '#1e1e20' : '#fff'} />
              : <IconPlay size={14} color={dark ? '#1e1e20' : '#fff'} />
            }
          </div>
          <PlayerButton size={26}>
            <IconNext size={14} />
          </PlayerButton>
          <PlayerButton active={repeatOn} onClick={onRepeatToggle} size={26}>
            <IconRepeat size={14} />
          </PlayerButton>
        </div>

        {/* Progress bar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, width: '100%' }}>
          <span style={{ fontSize: 10, fontWeight: 500, color: subColor, minWidth: 32, textAlign: 'right', fontVariantNumeric: 'tabular-nums' }}>
            {formatTime(progress)}
          </span>
          <div
            onClick={handleProgressClick}
            onMouseEnter={() => setHoverProgress(true)}
            onMouseLeave={() => setHoverProgress(false)}
            style={{
              flex: 1, height: hoverProgress ? 6 : 4, borderRadius: 3,
              background: trackBg, cursor: 'pointer', position: 'relative',
              transition: 'height 0.12s ease',
            }}
          >
            <div style={{
              height: '100%', borderRadius: 3,
              background: accent,
              width: `${(progress / duration) * 100}%`,
              transition: isDragging ? 'none' : 'width 0.3s linear',
              position: 'relative',
            }}>
              {hoverProgress && (
                <div style={{
                  position: 'absolute', right: -5, top: '50%', transform: 'translateY(-50%)',
                  width: 10, height: 10, borderRadius: '50%', background: accent,
                  boxShadow: '0 1px 4px rgba(0,0,0,0.2)',
                }}></div>
              )}
            </div>
          </div>
          <span style={{ fontSize: 10, fontWeight: 500, color: subColor, minWidth: 32, fontVariantNumeric: 'tabular-nums' }}>
            {formatTime(duration)}
          </span>
        </div>
      </div>

      {/* Right: Volume + extras */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, width: 220, flexShrink: 0, justifyContent: 'flex-end' }}>
        <PlayerButton size={24}>
          <IconQueue size={14} />
        </PlayerButton>
        <PlayerButton size={24}>
          <IconEqualizer size={14} />
        </PlayerButton>

        {/* Volume control */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ display: 'flex', color: iconColor }}>
            {volume === 0
              ? <IconVolumeMute size={14} />
              : <IconVolume size={14} />
            }
          </span>
          <div
            onClick={handleVolumeChange}
            style={{
              width: 80, height: 4, borderRadius: 2,
              background: trackBg, cursor: 'pointer', position: 'relative',
            }}
          >
            <div style={{
              height: '100%', borderRadius: 2,
              background: dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.45)',
              width: `${volume}%`,
            }}></div>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { NowPlayingBar });
