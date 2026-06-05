// cadence-player.jsx — Now Playing bar for Cadence

function NowPlayingBar({ dark, isPlaying, onPlayPause, shuffleOn, repeatOn, onShuffleToggle, onRepeatToggle, trackTitle, trackArtist, trackColors, trackDuration, queueOpen, onQueueToggle, eqOpen, onEqToggle }) {
  const [progress, setProgress] = React.useState(67);
  const [volume, setVolume] = React.useState(72);
  const [hoverProgress, setHoverProgress] = React.useState(false);
  const [hoverVolume, setHoverVolume] = React.useState(false);
  const duration = trackDuration || 234;

  const accent = dark ? '#0A84FF' : '#007AFF';
  const barBg = dark ? 'rgba(28,28,30,0.97)' : 'rgba(252,252,253,0.97)';
  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)';
  const textColor = dark ? 'rgba(255,255,255,0.92)' : 'rgba(0,0,0,0.88)';
  const subColor = dark ? 'rgba(255,255,255,0.45)' : 'rgba(0,0,0,0.42)';
  const iconColor = dark ? 'rgba(255,255,255,0.58)' : 'rgba(0,0,0,0.48)';
  const iconHoverColor = dark ? 'rgba(255,255,255,0.92)' : 'rgba(0,0,0,0.88)';
  const trackBg = dark ? 'rgba(255,255,255,0.13)' : 'rgba(0,0,0,0.1)';
  const activeIcon = accent;

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

  const handleVolumeClick = (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    setVolume(Math.floor(ratio * 100));
  };

  // Secondary icon button
  const IconButton = ({ children, onClick, active, size = 40 }) => {
    const [h, setH] = React.useState(false);
    return (
      <div
        onClick={onClick}
        onMouseEnter={() => setH(true)}
        onMouseLeave={() => setH(false)}
        style={{
          width: size, height: size, borderRadius: '50%',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer',
          color: active ? activeIcon : (h ? iconHoverColor : iconColor),
          background: h ? (dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)') : 'transparent',
          transition: 'color 0.12s, background 0.12s, transform 0.1s',
          transform: h ? 'scale(1.1)' : 'scale(1)',
          position: 'relative', flexShrink: 0,
        }}
      >
        {children}
        {active && (
          <div style={{
            position: 'absolute', bottom: 2, left: '50%', transform: 'translateX(-50%)',
            width: 4, height: 4, borderRadius: '50%', background: activeIcon,
          }}></div>
        )}
      </div>
    );
  };

  // Transport button (prev/next)
  const TransportButton = ({ children, onClick }) => {
    const [h, setH] = React.useState(false);
    return (
      <div
        onClick={onClick}
        onMouseEnter={() => setH(true)}
        onMouseLeave={() => setH(false)}
        style={{
          width: 44, height: 44, borderRadius: '50%',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer',
          color: h ? iconHoverColor : iconColor,
          transition: 'color 0.12s, transform 0.1s',
          transform: h ? 'scale(1.1)' : 'scale(1)',
          flexShrink: 0,
        }}
      >{children}</div>
    );
  };

  const coverColors = trackColors || ['#5c2d91', '#8e44ad', '#c39bd3'];
  const displayTitle = trackTitle || 'Static Dreams';
  const displayArtist = trackArtist || 'Neon Drift';

  return (
    <div style={{
      height: 96, flexShrink: 0,
      background: barBg,
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
      borderTop: `0.5px solid ${borderColor}`,
      display: 'flex', alignItems: 'center',
      padding: '0 20px',
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
    }}>

      {/* LEFT: Track info */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, width: 230, flexShrink: 0 }}>
        <div style={{
          width: 56, height: 56, borderRadius: 8, overflow: 'hidden', flexShrink: 0,
          boxShadow: '0 4px 14px rgba(0,0,0,0.22)',
          background: `linear-gradient(135deg, ${coverColors[0]} 0%, ${coverColors[1]} 50%, ${coverColors[2]} 100%)`,
          position: 'relative',
        }}>
          <div style={{
            position: 'absolute', top: '50%', left: '50%',
            transform: 'translate(-50%, -50%)',
            width: 22, height: 22, borderRadius: '50%',
            background: 'rgba(0,0,0,0.15)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <div style={{ width: 9, height: 9, borderRadius: '50%', background: 'rgba(0,0,0,0.25)' }}></div>
          </div>
        </div>
        <div style={{ minWidth: 0, flex: 1 }}>
          <div style={{
            fontSize: 13, fontWeight: 600, color: textColor,
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            lineHeight: '18px',
          }}>{displayTitle}</div>
          <div style={{
            fontSize: 12, fontWeight: 400, color: subColor,
            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
            lineHeight: '16px', marginTop: 2,
          }}>{displayArtist}</div>
        </div>
        <IconButton size={36}>
          <IconHeart size={17} />
        </IconButton>
      </div>

      {/* CENTER: Controls + Progress */}
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        alignItems: 'center', gap: 8,
        padding: '0 12px',
      }}>
        {/* Transport row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <IconButton active={shuffleOn} onClick={onShuffleToggle} size={40}>
            <IconShuffle size={20} />
          </IconButton>

          <TransportButton>
            <IconPrevious size={22} />
          </TransportButton>

          {/* Play/Pause */}
          <div
            onClick={onPlayPause}
            style={{
              width: 56, height: 56, borderRadius: '50%',
              background: textColor,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer',
              transition: 'transform 0.1s, box-shadow 0.12s',
              boxShadow: dark
                ? '0 3px 16px rgba(0,0,0,0.45)'
                : '0 3px 16px rgba(0,0,0,0.16)',
              flexShrink: 0,
              margin: '0 4px',
            }}
            onMouseEnter={e => {
              e.currentTarget.style.transform = 'scale(1.06)';
              e.currentTarget.style.boxShadow = dark ? '0 5px 24px rgba(0,0,0,0.55)' : '0 5px 24px rgba(0,0,0,0.22)';
            }}
            onMouseLeave={e => {
              e.currentTarget.style.transform = 'scale(1)';
              e.currentTarget.style.boxShadow = dark ? '0 3px 16px rgba(0,0,0,0.45)' : '0 3px 16px rgba(0,0,0,0.16)';
            }}
          >
            {isPlaying
              ? <IconPause size={22} color={dark ? '#1c1c1e' : '#ffffff'} />
              : <IconPlay size={22} color={dark ? '#1c1c1e' : '#ffffff'} />
            }
          </div>

          <TransportButton>
            <IconNext size={22} />
          </TransportButton>

          <IconButton active={repeatOn} onClick={onRepeatToggle} size={40}>
            <IconRepeat size={20} />
          </IconButton>
        </div>

        {/* Progress bar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, width: '100%', maxWidth: 440 }}>
          <span style={{
            fontSize: 11, fontWeight: 500, color: subColor,
            minWidth: 36, textAlign: 'right',
            fontVariantNumeric: 'tabular-nums',
          }}>{formatTime(progress)}</span>

          <div
            onClick={handleProgressClick}
            onMouseEnter={() => setHoverProgress(true)}
            onMouseLeave={() => setHoverProgress(false)}
            style={{ flex: 1, height: 20, display: 'flex', alignItems: 'center', cursor: 'pointer' }}
          >
            <div style={{
              width: '100%', height: hoverProgress ? 6 : 4,
              borderRadius: 3, background: trackBg, position: 'relative',
              transition: 'height 0.12s ease',
            }}>
              <div style={{
                height: '100%', borderRadius: 3, background: accent,
                width: `${(progress / duration) * 100}%`,
                position: 'relative', transition: 'width 0.3s linear',
              }}>
                {hoverProgress && (
                  <div style={{
                    position: 'absolute', right: -7, top: '50%', transform: 'translateY(-50%)',
                    width: 14, height: 14, borderRadius: '50%', background: accent,
                    boxShadow: '0 1px 6px rgba(0,0,0,0.28)',
                  }}></div>
                )}
              </div>
            </div>
          </div>

          <span style={{
            fontSize: 11, fontWeight: 500, color: subColor,
            minWidth: 36, fontVariantNumeric: 'tabular-nums',
          }}>{formatTime(duration)}</span>
        </div>
      </div>

      {/* RIGHT: Volume + extras */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 2, width: 230, flexShrink: 0, justifyContent: 'flex-end' }}>
        <IconButton size={38} active={queueOpen} onClick={onQueueToggle}>
          <IconQueue size={18} />
        </IconButton>
        <IconButton size={38} active={eqOpen} onClick={onEqToggle}>
          <IconEqualizer size={18} />
        </IconButton>

        {/* Volume */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginLeft: 6 }}>
          <span style={{ display: 'flex', flexShrink: 0, color: iconColor }}>
            {volume === 0 ? <IconVolumeMute size={18} /> : <IconVolume size={18} />}
          </span>
          <div
            onClick={handleVolumeClick}
            onMouseEnter={() => setHoverVolume(true)}
            onMouseLeave={() => setHoverVolume(false)}
            style={{ width: 100, height: 20, display: 'flex', alignItems: 'center', cursor: 'pointer', flexShrink: 0 }}
          >
            <div style={{
              width: '100%', height: hoverVolume ? 6 : 4,
              borderRadius: 3, background: trackBg, position: 'relative',
              transition: 'height 0.12s ease',
            }}>
              <div style={{
                height: '100%', borderRadius: 3,
                background: dark ? 'rgba(255,255,255,0.62)' : 'rgba(0,0,0,0.42)',
                width: `${volume}%`, position: 'relative',
              }}>
                {hoverVolume && (
                  <div style={{
                    position: 'absolute', right: -7, top: '50%', transform: 'translateY(-50%)',
                    width: 14, height: 14, borderRadius: '50%',
                    background: dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.55)',
                    boxShadow: '0 1px 5px rgba(0,0,0,0.22)',
                  }}></div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

    </div>
  );
}

Object.assign(window, { NowPlayingBar });
