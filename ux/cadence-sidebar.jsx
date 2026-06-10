// cadence-sidebar.jsx — macOS-native sidebar for Cadence

function CadenceSidebarItem({ icon, label, selected = false, badge, dark, onClick }) {
  const [hovered, setHovered] = React.useState(false);
  const accent = dark ? '#0A84FF' : '#007AFF';
  const textColor = dark ? 'rgba(255,255,255,0.85)' : 'rgba(0,0,0,0.85)';
  const iconColor = selected ? accent : (dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.45)');
  const hoverBg = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)';
  const selectedBg = dark ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.09)';

  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'flex', alignItems: 'center', gap: 8,
        height: 28, padding: '0 10px', margin: '0 8px',
        borderRadius: 6, cursor: 'pointer', position: 'relative',
        background: selected ? selectedBg : (hovered ? hoverBg : 'transparent'),
        transition: 'background 0.15s ease',
      }}
    >
      <span style={{ display: 'flex', flexShrink: 0, color: iconColor, transition: 'color 0.15s' }}>
        {icon}
      </span>
      <span style={{
        fontSize: 13, fontWeight: selected ? 600 : 400,
        color: selected ? textColor : (dark ? 'rgba(255,255,255,0.75)' : 'rgba(0,0,0,0.75)'),
        flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        letterSpacing: '-0.01em',
      }}>
        {label}
      </span>
      {badge && (
        <span style={{
          fontSize: 10, fontWeight: 600, color: '#fff', background: accent,
          borderRadius: 10, padding: '1px 6px', minWidth: 16, textAlign: 'center',
        }}>{badge}</span>
      )}
    </div>
  );
}

function CadenceSidebarSection({ title, dark }) {
  return (
    <div style={{
      padding: '16px 18px 4px',
      fontSize: 11, fontWeight: 700, letterSpacing: '0.02em',
      color: dark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.4)',
      textTransform: 'uppercase',
    }}>{title}</div>
  );
}

function PlaylistContextMenu({ x, y, dark, onDelete, onClose }) {
  const menuBg = dark ? 'rgba(50,50,54,0.96)' : 'rgba(255,255,255,0.96)';
  const borderColor = dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.08)';
  const [hovered, setHovered] = React.useState(false);

  React.useEffect(() => {
    const handler = (e) => { e.stopPropagation && null; onClose(); };
    window.addEventListener('click', handler);
    window.addEventListener('contextmenu', handler);
    return () => {
      window.removeEventListener('click', handler);
      window.removeEventListener('contextmenu', handler);
    };
  }, [onClose]);

  return (
    <div
      onClick={e => e.stopPropagation()}
      style={{
        position: 'fixed', left: x, top: y, zIndex: 2000,
        background: menuBg,
        backdropFilter: 'blur(30px) saturate(180%)',
        WebkitBackdropFilter: 'blur(30px) saturate(180%)',
        borderRadius: 8, padding: '4px 0',
        border: `0.5px solid ${borderColor}`,
        boxShadow: '0 8px 32px rgba(0,0,0,0.25), 0 2px 8px rgba(0,0,0,0.1)',
        minWidth: 160,
        fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
      }}
    >
      <div
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        onClick={() => { onDelete(); onClose(); }}
        style={{
          display: 'flex', alignItems: 'center', gap: 8,
          padding: '5px 12px', borderRadius: 4, cursor: 'default',
          background: hovered ? '#FF3B30' : 'transparent',
          color: hovered ? '#fff' : '#FF3B30',
          fontSize: 13, fontWeight: 400,
          transition: 'background 0.08s, color 0.08s',
        }}
      >
        Удалить
      </div>
    </div>
  );
}

function CadenceSidebar({ dark, activeItem, onItemClick, onSettingsClick }) {
  const accent = dark ? '#0A84FF' : '#007AFF';
  const sidebarBg = dark
    ? 'rgba(40,40,45,0.82)'
    : 'rgba(245,245,247,0.72)';
  const borderColor = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)';

  const libraryItems = [
    { id: 'tracks', icon: <IconMusicNote size={15} />, label: 'Все треки' },
    { id: 'albums', icon: <IconAlbum size={15} />, label: 'Альбомы' },
    { id: 'artists', icon: <IconArtist size={15} />, label: 'Артисты' },
  ];

  const [playlists, setPlaylists] = React.useState([
    { id: 'pl-chill', label: 'Вечерний чилл' },
    { id: 'pl-workout', label: 'Тренировка' },
    { id: 'pl-focus', label: 'Фокус' },
    { id: 'pl-drive', label: 'В дорогу' },
  ]);
  const [contextMenu, setContextMenu] = React.useState(null);

  const handlePlaylistContextMenu = (e, pl) => {
    e.preventDefault();
    e.stopPropagation();
    setContextMenu({ x: e.clientX, y: e.clientY, id: pl.id });
  };

  const deletePlaylist = (id) => {
    setPlaylists(prev => prev.filter(p => p.id !== id));
    if (activeItem === id) onItemClick('albums');
  };

  return (
    <div style={{
      width: 220, height: '100%', flexShrink: 0,
      background: sidebarBg,
      backdropFilter: 'blur(50px) saturate(180%)',
      WebkitBackdropFilter: 'blur(50px) saturate(180%)',
      borderRight: `0.5px solid ${borderColor}`,
      display: 'flex', flexDirection: 'column',
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
      userSelect: 'none',
      overflow: 'hidden',
    }}>
      {/* Traffic lights area */}
      <div style={{
        height: 52, display: 'flex', alignItems: 'center',
        padding: '0 18px', flexShrink: 0,
      }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <div style={{ width: 12, height: 12, borderRadius: '50%', background: '#FF5F57', border: '0.5px solid rgba(0,0,0,0.12)' }}></div>
          <div style={{ width: 12, height: 12, borderRadius: '50%', background: '#FEBC2E', border: '0.5px solid rgba(0,0,0,0.12)' }}></div>
          <div style={{ width: 12, height: 12, borderRadius: '50%', background: '#28C840', border: '0.5px solid rgba(0,0,0,0.12)' }}></div>
        </div>
      </div>

      {/* Scrollable content */}
      <div style={{
        flex: 1, overflowY: 'auto', overflowX: 'hidden',
        display: 'flex', flexDirection: 'column', gap: 1,
        paddingBottom: 12,
      }}>
        {/* Now Playing link */}
        <div style={{ padding: '0 0 4px' }}>
          <CadenceSidebarItem
            icon={<IconNowPlaying size={15} color={activeItem === 'nowplaying' ? accent : undefined} />}
            label="Сейчас играет"
            selected={activeItem === 'nowplaying'}
            dark={dark}
            onClick={() => onItemClick('nowplaying')}
          />
        </div>

        <div style={{ height: 0.5, background: borderColor, margin: '4px 16px' }}></div>

        {/* Library */}
        <CadenceSidebarSection title="Библиотека" dark={dark} />
        {libraryItems.map(item => (
          <CadenceSidebarItem
            key={item.id}
            icon={React.cloneElement(item.icon, { color: activeItem === item.id ? accent : undefined })}
            label={item.label}
            selected={activeItem === item.id}
            dark={dark}
            onClick={() => onItemClick(item.id)}
          />
        ))}

        <div style={{ height: 0.5, background: borderColor, margin: '8px 16px' }}></div>

        {/* Playlists */}
        <CadenceSidebarSection title="Плейлисты" dark={dark} />
        {playlists.map(pl => (
          <div key={pl.id} onContextMenu={e => handlePlaylistContextMenu(e, pl)}>
            <CadenceSidebarItem
              icon={<IconPlaylist size={15} />}
              label={pl.label}
              selected={activeItem === pl.id}
              dark={dark}
              onClick={() => onItemClick(pl.id)}
            />
          </div>
        ))}
        {contextMenu && (
          <PlaylistContextMenu
            x={contextMenu.x}
            y={contextMenu.y}
            dark={dark}
            onDelete={() => deletePlaylist(contextMenu.id)}
            onClose={() => setContextMenu(null)}
          />
        )}
        {/* Create playlist button */}
        <div
          style={{
            display: 'flex', alignItems: 'center', gap: 6,
            padding: '4px 10px', margin: '2px 8px',
            borderRadius: 6, cursor: 'pointer',
            color: dark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.35)',
            fontSize: 12,
          }}
          onMouseEnter={e => e.currentTarget.style.color = accent}
          onMouseLeave={e => e.currentTarget.style.color = dark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.35)'}
        >
          <IconPlus size={13} />
          <span>Создать плейлист</span>
        </div>

        <div style={{ height: 0.5, background: borderColor, margin: '8px 16px' }}></div>

        {/* Extra sections */}
        <CadenceSidebarItem
          icon={<IconHeart size={15} color={activeItem === 'favorites' ? '#FF375F' : undefined} />}
          label="Избранное"
          selected={activeItem === 'favorites'}
          dark={dark}
          onClick={() => onItemClick('favorites')}
        />
        <CadenceSidebarItem
          icon={<IconRecent size={15} />}
          label="Недавнее"
          selected={activeItem === 'recent'}
          dark={dark}
          onClick={() => onItemClick('recent')}
        />
        <CadenceSidebarItem
          icon={<IconDownload size={15} />}
          label="Скачанное"
          selected={activeItem === 'downloaded'}
          badge="12"
          dark={dark}
          onClick={() => onItemClick('downloaded')}
        />
      </div>

      {/* Settings button at bottom */}
      <div style={{ flexShrink: 0, padding: '6px 8px 10px', borderTop: `0.5px solid ${borderColor}` }}>
        <div
          onClick={onSettingsClick}
          style={{
            display: 'flex', alignItems: 'center', gap: 8,
            height: 28, padding: '0 10px', borderRadius: 6, cursor: 'pointer',
            color: dark ? 'rgba(255,255,255,0.42)' : 'rgba(0,0,0,0.36)',
            transition: 'background 0.12s, color 0.12s',
          }}
          onMouseEnter={e => { e.currentTarget.style.background = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)'; e.currentTarget.style.color = dark ? 'rgba(255,255,255,0.75)' : 'rgba(0,0,0,0.65)'; }}
          onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = dark ? 'rgba(255,255,255,0.42)' : 'rgba(0,0,0,0.36)'; }}
        >
          <IconSettings size={14} color="currentColor" />
          <span style={{ fontSize: 12 }}>Настройки</span>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { CadenceSidebar, CadenceSidebarItem, CadenceSidebarSection });
