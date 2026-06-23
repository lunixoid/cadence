// cadence-queue.jsx — Slide-in queue panel for Cadence

function QueueMiniCover({ colors, size = 32 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: 5, flexShrink: 0,
      background: `linear-gradient(135deg, ${colors[0]} 0%, ${colors[1]} 50%, ${colors[2]} 100%)`,
      position: 'relative', overflow: 'hidden',
    }}>
      <div style={{
        position: 'absolute', top: '50%', left: '50%',
        transform: 'translate(-50%, -50%)',
        width: size * 0.38, height: size * 0.38, borderRadius: '50%',
        background: 'rgba(0,0,0,0.15)',
      }}></div>
    </div>
  );
}

function QueueTrackRow({ track, dark, onRemove, showDragHandle, dimmed, isNowPlaying,
                          onDragStart, onDragOver, onDrop, isDragOver }) {
  const [hovered, setHovered] = React.useState(false);
  const accent = dark ? '#0A84FF' : '#007AFF';
  const textColor = dark
    ? (dimmed ? 'rgba(255,255,255,0.42)' : 'rgba(255,255,255,0.88)')
    : (dimmed ? 'rgba(0,0,0,0.36)'       : 'rgba(0,0,0,0.85)');
  const subColor = dark
    ? (dimmed ? 'rgba(255,255,255,0.24)' : 'rgba(255,255,255,0.42)')
    : (dimmed ? 'rgba(0,0,0,0.22)'       : 'rgba(0,0,0,0.40)');
  const hoverBg  = dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)';
  const dropLine = `1.5px solid ${accent}`;

  return (
    <div
      draggable={showDragHandle}
      onDragStart={onDragStart}
      onDragOver={onDragOver}
      onDrop={onDrop}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: isNowPlaying ? '6px 12px 6px 12px' : '4px 12px 4px 8px',
        margin: '0 4px', borderRadius: 6,
        background: isDragOver ? (dark ? 'rgba(10,132,255,0.1)' : 'rgba(0,122,255,0.07)') : (hovered ? hoverBg : 'transparent'),
        borderTop: isDragOver ? dropLine : '1.5px solid transparent',
        transition: 'background 0.1s ease',
        cursor: showDragHandle ? 'grab' : 'default',
      }}
    >
      {/* Drag handle ≡ */}
      {showDragHandle ? (
        <div style={{
          width: 12, height: 12, flexShrink: 0,
          display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 2.5,
          opacity: hovered ? 0.55 : 0.18,
          transition: 'opacity 0.12s',
        }}>
          {[0,1,2].map(i => (
            <div key={i} style={{ height: 1.5, borderRadius: 1, background: dark ? '#fff' : '#000' }}></div>
          ))}
        </div>
      ) : (
        !isNowPlaying && <div style={{ width: 12, flexShrink: 0 }}></div>
      )}

      {/* Album cover */}
      <QueueMiniCover colors={track.colors} size={isNowPlaying ? 40 : 32} />

      {/* Track info */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: 12, lineHeight: '16px',
          fontWeight: isNowPlaying ? 600 : 400,
          color: isNowPlaying ? accent : textColor,
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>{track.title}</div>
        <div style={{
          fontSize: 11, lineHeight: '15px', marginTop: 1,
          color: subColor,
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>{track.artist}</div>
      </div>

      {/* Remove × — only on hover for next tracks */}
      {onRemove && (
        <div
          onClick={e => { e.stopPropagation(); onRemove(); }}
          style={{
            width: 18, height: 18, borderRadius: '50%', flexShrink: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            opacity: hovered ? 1 : 0,
            background: dark ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.08)',
            cursor: 'pointer',
            transition: 'opacity 0.12s',
            fontSize: 12, fontWeight: 500,
            color: dark ? 'rgba(255,255,255,0.7)' : 'rgba(0,0,0,0.5)',
            lineHeight: 1,
          }}
        >×</div>
      )}
    </div>
  );
}

function QueueSectionHeader({ title, dark, action, onAction }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '12px 16px 5px',
    }}>
      <span style={{
        fontSize: 11, fontWeight: 700, letterSpacing: '0.05em',
        textTransform: 'uppercase',
        color: dark ? 'rgba(255,255,255,0.36)' : 'rgba(0,0,0,0.34)',
      }}>{title}</span>
      {action && (
        <span
          onClick={onAction}
          style={{
            fontSize: 11, fontWeight: 500, cursor: 'pointer',
            color: dark ? '#0A84FF' : '#007AFF',
          }}
          onMouseEnter={e => e.currentTarget.style.opacity = '0.75'}
          onMouseLeave={e => e.currentTarget.style.opacity = '1'}
        >{action}</span>
      )}
    </div>
  );
}

function QueuePanel({ dark, isOpen, onClose, currentTrack, currentAlbum }) {
  const panelBg    = dark ? 'rgba(36,36,40,0.9)'  : 'rgba(247,247,249,0.9)';
  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)';
  const dividerColor = dark ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.06)';
  const textColor  = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.88)';

  const [nextTracks, setNextTracks] = React.useState(() => [
    { id: 'n1', title: 'Golden Hour',   artist: 'Sundial',       colors: ALBUM_DATA[6].colors  },
    { id: 'n2', title: 'Облака',        artist: 'Виктория Ши',   colors: ALBUM_DATA[7].colors  },
    { id: 'n3', title: 'Pulse',         artist: 'Voltage',       colors: ALBUM_DATA[10].colors },
  ]);

  // Autoplay: remaining tracks from current album
  const autoTracks = React.useMemo(() => {
    if (!currentAlbum) return [];
    const allTracks = getAlbumTracks(currentAlbum);
    const curIdx = currentTrack
      ? allTracks.findIndex(t => t.title === currentTrack.title)
      : -1;
    return allTracks
      .slice(curIdx >= 0 ? curIdx + 1 : 0)
      .slice(0, 7)
      .map(t => ({
        id: `auto-${t.index}`,
        title: t.title,
        artist: currentAlbum.artist,
        colors: currentAlbum.colors,
      }));
  }, [currentAlbum, currentTrack]);

  // Drag state for "Далее"
  const [dragIdx, setDragIdx]     = React.useState(null);
  const [dragOverIdx, setDragOverIdx] = React.useState(null);

  const handleDrop = (idx) => {
    if (dragIdx === null || dragIdx === idx) { setDragIdx(null); setDragOverIdx(null); return; }
    const arr = [...nextTracks];
    const [moved] = arr.splice(dragIdx, 1);
    arr.splice(idx, 0, moved);
    setNextTracks(arr);
    setDragIdx(null); setDragOverIdx(null);
  };

  const nowPlayingTrack = {
    title:  currentTrack?.title  || 'Static Dreams',
    artist: currentAlbum?.artist || 'Neon Drift',
    colors: currentAlbum?.colors || ['#5c2d91','#8e44ad','#c39bd3'],
  };

  return (
    /* Outer wrapper animates width */
    <div style={{
      width: isOpen ? 300 : 0,
      transition: 'width 0.28s cubic-bezier(0.4, 0, 0.2, 1)',
      flexShrink: 0, overflow: 'hidden',
      borderLeft: `0.5px solid ${isOpen ? borderColor : 'transparent'}`,
    }}>
      {/* Inner panel — fixed 300px so content doesn't squish during animation */}
      <div style={{
        width: 300, height: '100%',
        background: panelBg,
        backdropFilter: 'blur(50px) saturate(180%)',
        WebkitBackdropFilter: 'blur(50px) saturate(180%)',
        display: 'flex', flexDirection: 'column',
        fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
        userSelect: 'none',
      }}>

        {/* Header */}
        <div style={{
          height: 52, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '0 12px 0 16px', flexShrink: 0,
          borderBottom: `0.5px solid ${borderColor}`,
        }}>
          <span style={{ fontSize: 15, fontWeight: 700, letterSpacing: '-0.015em', color: textColor }}>
            Очередь
          </span>
          <div
            onClick={onClose}
            style={{
              width: 22, height: 22, borderRadius: '50%',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer',
              color: dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.45)',
              background: dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.07)',
              transition: 'background 0.1s',
            }}
            onMouseEnter={e => e.currentTarget.style.background = dark ? 'rgba(255,255,255,0.18)' : 'rgba(0,0,0,0.13)'}
            onMouseLeave={e => e.currentTarget.style.background = dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.07)'}
          >
            <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
              <path d="M1 1L9 9M9 1L1 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
          </div>
        </div>

        {/* Scrollable body */}
        <div style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', paddingBottom: 16 }}>

          {/* 1 — Сейчас играет */}
          <QueueSectionHeader title="Сейчас играет" dark={dark} />
          <QueueTrackRow track={nowPlayingTrack} dark={dark} isNowPlaying showDragHandle={false} />

          <div style={{ height: 1, background: dividerColor, margin: '10px 12px 2px' }}></div>

          {/* 2 — Далее */}
          <QueueSectionHeader
            title="Далее"
            dark={dark}
            action={nextTracks.length > 0 ? 'Очистить' : null}
            onAction={() => setNextTracks([])}
          />
          {nextTracks.length === 0 ? (
            <div style={{
              padding: '6px 16px 4px',
              fontSize: 12, fontStyle: 'italic',
              color: dark ? 'rgba(255,255,255,0.28)' : 'rgba(0,0,0,0.26)',
            }}>Нет треков</div>
          ) : nextTracks.map((track, idx) => (
            <QueueTrackRow
              key={track.id}
              track={track}
              dark={dark}
              showDragHandle
              onRemove={() => setNextTracks(p => p.filter(t => t.id !== track.id))}
              onDragStart={() => setDragIdx(idx)}
              onDragOver={e => { e.preventDefault(); setDragOverIdx(idx); }}
              onDrop={() => handleDrop(idx)}
              isDragOver={dragOverIdx === idx && dragIdx !== idx}
            />
          ))}

          <div style={{ height: 1, background: dividerColor, margin: '10px 12px 2px' }}></div>

          {/* 3 — Автовоспроизведение */}
          <QueueSectionHeader title="Автовоспроизведение" dark={dark} />
          {autoTracks.map(track => (
            <QueueTrackRow
              key={track.id}
              track={track}
              dark={dark}
              showDragHandle={false}
              dimmed
            />
          ))}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { QueuePanel, QueueMiniCover, QueueTrackRow, QueueSectionHeader });
