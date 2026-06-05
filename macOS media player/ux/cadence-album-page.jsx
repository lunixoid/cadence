// cadence-album-page.jsx — Album detail page for Cadence

// Generate track data for each album
const ALBUM_TRACKS = {};
const TRACK_NAMES_POOL = [
  ['Into the Void', 'Fading Light', 'Resonance', 'Parallel Lines', 'Eventide',
   'Lucid State', 'Undertow', 'Silver Thread', 'Aether', 'Penumbra', 'Last Signal', 'Zero Point'],
  ['Дыхание', 'Горизонт', 'Эхо', 'Свет и тень', 'Сквозь облака',
   'Тихий шторм', 'Мерцание', 'На краю', 'Простор', 'Рассвет', 'Глубина', 'Финал'],
];

function getAlbumTracks(album) {
  if (ALBUM_TRACKS[album.id]) return ALBUM_TRACKS[album.id];
  // Use Russian names for Russian albums
  const isRussian = /[а-яА-Я]/.test(album.title);
  const pool = isRussian ? TRACK_NAMES_POOL[1] : TRACK_NAMES_POOL[0];
  const count = 10 + (album.id % 3); // 10-12 tracks
  const tracks = [];
  for (let i = 0; i < count; i++) {
    const mins = 2 + ((album.id * 7 + i * 13) % 4);
    const secs = (album.id * 11 + i * 17) % 60;
    tracks.push({
      index: i + 1,
      title: pool[i % pool.length],
      duration: mins * 60 + secs,
    });
  }
  ALBUM_TRACKS[album.id] = tracks;
  return tracks;
}

function getAlbumMeta(album) {
  const tracks = getAlbumTracks(album);
  const totalSec = tracks.reduce((s, t) => s + t.duration, 0);
  const totalMin = Math.floor(totalSec / 60);
  const years = [2019, 2020, 2021, 2022, 2023, 2024];
  return {
    year: years[album.id % years.length],
    trackCount: tracks.length,
    totalMin,
  };
}

// Animated equalizer bars for "now playing" indicator
function EqualizerBars({ color, size = 12 }) {
  const barStyle = (delay) => ({
    width: 2.5, borderRadius: 1, background: color,
    animation: `eqBounce 0.8s ${delay}s ease-in-out infinite alternate`,
  });
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-end', gap: 1.5,
      height: size, width: size,
    }}>
      <div style={barStyle(0)}></div>
      <div style={barStyle(0.2)}></div>
      <div style={barStyle(0.4)}></div>
    </div>
  );
}

// Context menu component
function TrackContextMenu({ x, y, dark, onClose, trackTitle }) {
  const menuBg = dark ? 'rgba(50,50,54,0.96)' : 'rgba(255,255,255,0.96)';
  const textColor = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.85)';
  const hoverBg = dark ? '#0A84FF' : '#007AFF';
  const borderColor = dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.08)';
  const subColor = dark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.35)';

  const items = [
    { label: 'Воспроизвести далее', shortcut: null },
    { label: 'Добавить в очередь', shortcut: null },
    { divider: true },
    { label: 'Добавить в плейлист', arrow: true },
    { label: 'В избранное', shortcut: '♥' },
    { label: 'Оценить', arrow: true },
    { divider: true },
    { label: 'Показать в Finder', shortcut: null },
  ];

  React.useEffect(() => {
    const handler = () => onClose();
    window.addEventListener('click', handler);
    return () => window.removeEventListener('click', handler);
  }, [onClose]);

  const MenuItem = ({ item }) => {
    const [h, setH] = React.useState(false);
    if (item.divider) {
      return <div style={{ height: 1, background: borderColor, margin: '4px 0' }}></div>;
    }
    return (
      <div
        onMouseEnter={() => setH(true)}
        onMouseLeave={() => setH(false)}
        style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '5px 12px', borderRadius: 4, cursor: 'default',
          background: h ? hoverBg : 'transparent',
          color: h ? '#fff' : textColor,
          fontSize: 13, fontWeight: 400,
          transition: 'background 0.08s, color 0.08s',
        }}
      >
        <span>{item.label}</span>
        {item.arrow && <span style={{ fontSize: 10, opacity: 0.6 }}>▶</span>}
        {item.shortcut && <span style={{ fontSize: 11, color: h ? 'rgba(255,255,255,0.6)' : subColor }}>{item.shortcut}</span>}
      </div>
    );
  };

  return (
    <div style={{
      position: 'fixed', left: x, top: y, zIndex: 1000,
      background: menuBg,
      backdropFilter: 'blur(30px) saturate(180%)',
      WebkitBackdropFilter: 'blur(30px) saturate(180%)',
      borderRadius: 8, padding: '4px 0',
      border: `0.5px solid ${borderColor}`,
      boxShadow: '0 8px 32px rgba(0,0,0,0.25), 0 2px 8px rgba(0,0,0,0.1)',
      minWidth: 200,
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
    }}>
      {items.map((item, i) => <MenuItem key={i} item={item} />)}
    </div>
  );
}

// Main Album Page
function AlbumPage({ album, dark, playingTrackIdx, isPlaying, onPlayTrack, onBack }) {
  const [contextMenu, setContextMenu] = React.useState(null);
  const [hoveredRow, setHoveredRow] = React.useState(null);
  const tracks = getAlbumTracks(album);
  const meta = getAlbumMeta(album);

  const accent = dark ? '#0A84FF' : '#007AFF';
  const textColor = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.85)';
  const subColor = dark ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.5)';
  const mutedColor = dark ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.3)';
  const borderColor = dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)';
  const rowHoverBg = dark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.03)';
  const headerBorderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)';

  const formatTime = (s) => {
    const m = Math.floor(s / 60);
    const sec = Math.floor(s % 60);
    return `${m}:${sec.toString().padStart(2, '0')}`;
  };

  const handleContextMenu = (e, track) => {
    e.preventDefault();
    setContextMenu({ x: e.clientX, y: e.clientY, track });
  };

  // Dominant color background for hero
  const dominantColor = album.colors[1];
  const heroBg = dark
    ? `linear-gradient(180deg, ${dominantColor}22 0%, transparent 100%)`
    : `linear-gradient(180deg, ${dominantColor}18 0%, transparent 100%)`;

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Toolbar with back button */}
      <div style={{
        height: 52, display: 'flex', alignItems: 'center', gap: 12,
        padding: '0 20px', flexShrink: 0,
        borderBottom: `0.5px solid ${borderColor}`,
      }}>
        <div
          onClick={onBack}
          style={{
            width: 28, height: 28, borderRadius: 6,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)',
            cursor: 'pointer',
          }}
        >
          <IconChevronLeft size={14} color={dark ? 'rgba(255,255,255,0.65)' : 'rgba(0,0,0,0.5)'} />
        </div>
        <span style={{
          fontSize: 13, fontWeight: 500, color: subColor,
          cursor: 'pointer',
        }} onClick={onBack}>Альбомы</span>
        <div style={{ flex: 1 }}></div>
      </div>

      {/* Scrollable content */}
      <div style={{
        flex: 1, overflowY: 'auto', overflowX: 'hidden',
      }}>
        {/* Hero section */}
        <div style={{
          padding: '28px 28px 20px',
          background: heroBg,
          display: 'flex', gap: 24, alignItems: 'flex-end',
        }}>
          {/* Large album cover */}
          <div style={{
            width: 180, height: 180, borderRadius: 10, overflow: 'hidden',
            flexShrink: 0,
            background: `linear-gradient(135deg, ${album.colors[0]} 0%, ${album.colors[1]} 50%, ${album.colors[2]} 100%)`,
            boxShadow: `0 8px 32px ${album.colors[1]}55, 0 2px 8px rgba(0,0,0,0.15)`,
            position: 'relative',
          }}>
            {/* Vinyl disc */}
            <div style={{
              position: 'absolute', top: '50%', left: '50%',
              transform: 'translate(-50%, -50%)',
              width: 68, height: 68, borderRadius: '50%',
              background: 'rgba(0,0,0,0.15)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <div style={{
                width: 27, height: 27, borderRadius: '50%',
                background: 'rgba(0,0,0,0.25)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <div style={{ width: 10, height: 10, borderRadius: '50%', background: 'rgba(255,255,255,0.2)' }}></div>
              </div>
            </div>
            <div style={{
              position: 'absolute', top: 16, left: 12,
              width: 80, height: 55, borderRadius: '50%',
              background: 'rgba(255,255,255,0.08)',
            }}></div>
          </div>

          {/* Album info */}
          <div style={{ flex: 1, minWidth: 0, paddingBottom: 4 }}>
            <div style={{
              fontSize: 26, fontWeight: 700, color: textColor,
              letterSpacing: '-0.025em', lineHeight: '32px',
              marginBottom: 4,
            }}>{album.title}</div>
            <div style={{
              fontSize: 16, fontWeight: 500, color: accent,
              cursor: 'pointer', marginBottom: 8,
              lineHeight: '22px',
            }}>{album.artist}</div>
            <div style={{
              fontSize: 12, color: subColor, display: 'flex', gap: 6,
              alignItems: 'center', marginBottom: 16,
            }}>
              <span>{meta.year}</span>
              <span style={{ opacity: 0.4 }}>·</span>
              <span>{meta.trackCount} треков</span>
              <span style={{ opacity: 0.4 }}>·</span>
              <span>{meta.totalMin} мин</span>
            </div>

            {/* Action buttons */}
            <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
              {/* Play button */}
              <button
                onClick={() => onPlayTrack(0)}
                style={{
                  display: 'flex', alignItems: 'center', gap: 6,
                  padding: '7px 18px', borderRadius: 8,
                  background: accent, border: 'none', cursor: 'pointer',
                  color: '#fff', fontSize: 13, fontWeight: 600,
                  fontFamily: 'inherit',
                  transition: 'filter 0.12s',
                }}
                onMouseEnter={e => e.currentTarget.style.filter = 'brightness(1.1)'}
                onMouseLeave={e => e.currentTarget.style.filter = 'brightness(1)'}
              >
                <IconPlay size={12} color="#fff" />
                Воспроизвести
              </button>
              {/* Shuffle */}
              <button
                onClick={() => onPlayTrack(Math.floor(Math.random() * tracks.length))}
                style={{
                  display: 'flex', alignItems: 'center', gap: 6,
                  padding: '7px 14px', borderRadius: 8,
                  background: dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)',
                  border: `0.5px solid ${dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.08)'}`,
                  cursor: 'pointer', color: textColor, fontSize: 13, fontWeight: 500,
                  fontFamily: 'inherit',
                  transition: 'background 0.12s',
                }}
                onMouseEnter={e => e.currentTarget.style.background = dark ? 'rgba(255,255,255,0.14)' : 'rgba(0,0,0,0.09)'}
                onMouseLeave={e => e.currentTarget.style.background = dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)'}
              >
                <IconShuffle size={12} />
                Перемешать
              </button>
              {/* More button */}
              <div style={{
                width: 32, height: 32, borderRadius: 8,
                background: dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)',
                border: `0.5px solid ${dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.08)'}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                cursor: 'pointer', fontSize: 16, color: subColor, fontWeight: 700,
                letterSpacing: '1px',
              }}>⋯</div>
            </div>
          </div>
        </div>

        {/* Track list header */}
        <div style={{
          display: 'grid', gridTemplateColumns: '40px 1fr 60px',
          padding: '8px 28px', gap: 0,
          borderBottom: `1px solid ${headerBorderColor}`,
          color: mutedColor, fontSize: 11, fontWeight: 600,
          textTransform: 'uppercase', letterSpacing: '0.04em',
        }}>
          <span style={{ textAlign: 'center' }}>#</span>
          <span>Название</span>
          <span style={{ textAlign: 'right' }}>
            <IconRecent size={11} color={mutedColor} />
          </span>
        </div>

        {/* Track rows */}
        {tracks.map((track, i) => {
          const isActive = i === playingTrackIdx;
          const isHovered = hoveredRow === i;
          return (
            <div
              key={i}
              onMouseEnter={() => setHoveredRow(i)}
              onMouseLeave={() => setHoveredRow(null)}
              onContextMenu={(e) => handleContextMenu(e, track)}
              onDoubleClick={() => onPlayTrack(i)}
              style={{
                display: 'grid', gridTemplateColumns: '40px 1fr 60px',
                padding: '0 28px', height: 38, alignItems: 'center',
                background: isHovered ? rowHoverBg : 'transparent',
                borderRadius: 0, cursor: 'default',
                transition: 'background 0.08s',
              }}
            >
              {/* Track number / play icon / equalizer */}
              <span style={{
                textAlign: 'center', fontSize: 13, fontWeight: 400,
                color: isActive ? accent : subColor,
                fontVariantNumeric: 'tabular-nums',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                {isActive && isPlaying ? (
                  <EqualizerBars color={accent} size={13} />
                ) : isHovered ? (
                  <span onClick={() => onPlayTrack(i)} style={{ cursor: 'pointer', display: 'flex' }}>
                    <IconPlay size={11} color={isActive ? accent : textColor} />
                  </span>
                ) : isActive ? (
                  <IconPause size={11} color={accent} />
                ) : (
                  track.index
                )}
              </span>

              {/* Track title */}
              <span style={{
                fontSize: 13, fontWeight: isActive ? 600 : 400,
                color: isActive ? accent : textColor,
                overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                paddingRight: 12,
              }}>{track.title}</span>

              {/* Duration */}
              <span style={{
                textAlign: 'right', fontSize: 12, color: subColor,
                fontVariantNumeric: 'tabular-nums',
              }}>{formatTime(track.duration)}</span>
            </div>
          );
        })}

        {/* Bottom spacing */}
        <div style={{ height: 24 }}></div>
      </div>

      {/* Context menu */}
      {contextMenu && (
        <TrackContextMenu
          x={contextMenu.x}
          y={contextMenu.y}
          dark={dark}
          trackTitle={contextMenu.track.title}
          onClose={() => setContextMenu(null)}
        />
      )}
    </div>
  );
}

Object.assign(window, { AlbumPage, getAlbumTracks, getAlbumMeta, EqualizerBars, TrackContextMenu });
