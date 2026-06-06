// cadence-content.jsx — Album grid + toolbar for Cadence

const ALBUM_DATA = [
  { id: 1, title: 'Midnight Echoes', artist: 'Luna Solaris', colors: ['#1a1a2e', '#16213e', '#0f3460'] },
  { id: 2, title: 'Amber Waves', artist: 'The Coastline', colors: ['#e6a157', '#d4782f', '#b85c1e'] },
  { id: 3, title: 'Static Dreams', artist: 'Neon Drift', colors: ['#5c2d91', '#8e44ad', '#c39bd3'] },
  { id: 4, title: 'Ocean Floor', artist: 'Deep Current', colors: ['#1b4f72', '#2980b9', '#5dade2'] },
  { id: 5, title: 'Тишина', artist: 'Артём Ветров', colors: ['#2d3436', '#636e72', '#b2bec3'] },
  { id: 6, title: 'Восход', artist: 'Марина Лес', colors: ['#fd7272', '#fc5185', '#f78fb3'] },
  { id: 7, title: 'Golden Hour', artist: 'Sundial', colors: ['#f39c12', '#e67e22', '#d35400'] },
  { id: 8, title: 'Облака', artist: 'Виктория Ши', colors: ['#74b9ff', '#a29bfe', '#dfe6e9'] },
  { id: 9, title: 'Concrete Garden', artist: 'Ivy Wall', colors: ['#27ae60', '#2ecc71', '#a3cb38'] },
  { id: 10, title: 'Полярная ночь', artist: 'Север', colors: ['#2c3e50', '#34495e', '#4a6fa5'] },
  { id: 11, title: 'Pulse', artist: 'Voltage', colors: ['#e74c3c', '#c0392b', '#922b21'] },
  { id: 12, title: 'Afterglow', artist: 'Haze', colors: ['#fdcb6e', '#ffeaa7', '#fab1a0'] },
];

let _coverIdCounter = 0;

function AlbumCover({ colors, size = 148 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: 8, overflow: 'hidden',
      position: 'relative', flexShrink: 0,
      background: `linear-gradient(135deg, ${colors[0]} 0%, ${colors[1]} 50%, ${colors[2]} 100%)`,
    }}>
      {/* Vinyl disc hint */}
      <div style={{
        position: 'absolute', top: '50%', left: '50%',
        transform: 'translate(-50%, -50%)',
        width: 56, height: 56, borderRadius: '50%',
        background: 'rgba(0,0,0,0.15)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <div style={{
          width: 22, height: 22, borderRadius: '50%',
          background: 'rgba(0,0,0,0.25)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'rgba(255,255,255,0.2)' }}></div>
        </div>
      </div>
      {/* Subtle light reflection */}
      <div style={{
        position: 'absolute', top: 14, left: 10,
        width: 70, height: 50, borderRadius: '50%',
        background: 'rgba(255,255,255,0.08)',
      }}></div>
    </div>
  );
}

function AlbumCard({ album, dark, onClick }) {
  const [hovered, setHovered] = React.useState(false);
  const textColor = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.85)';
  const subColor = dark ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.5)';

  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        width: 160, cursor: 'pointer',
        borderRadius: 10, padding: 6,
        background: hovered ? (dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)') : 'transparent',
        transition: 'background 0.15s ease',
      }}
    >
      <div style={{ position: 'relative' }}>
        <AlbumCover colors={album.colors} />
        {/* Play button overlay on hover */}
        {hovered && (
          <div style={{
            position: 'absolute', bottom: 8, right: 8,
            width: 32, height: 32, borderRadius: '50%',
            background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(10px)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            animation: 'fadeIn 0.15s ease',
          }}>
            <IconPlay size={14} color="white" />
          </div>
        )}
        {/* Subtle shadow under cover */}
        <div style={{
          position: 'absolute', bottom: -4, left: 8, right: 8, height: 8,
          background: `linear-gradient(to bottom, ${album.colors[1]}44, transparent)`,
          borderRadius: '0 0 8px 8px', filter: 'blur(6px)',
        }}></div>
      </div>
      <div style={{ marginTop: 8, padding: '0 2px' }}>
        <div style={{
          fontSize: 12, fontWeight: 500, color: textColor,
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          lineHeight: '16px',
        }}>{album.title}</div>
        <div style={{
          fontSize: 11, fontWeight: 400, color: subColor,
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          lineHeight: '15px', marginTop: 1,
        }}>{album.artist}</div>
      </div>
    </div>
  );
}

function CadenceToolbar({ dark, title = 'Альбомы', canGoBack = false, canGoForward = false, onBack, onForward }) {
  const textColor = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.85)';
  const mutedColor = dark ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.3)';
  const iconColor = dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.5)';
  const searchBg = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)';
  const searchBorder = dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.08)';
  const navBg = dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)';
  const navActiveBg = dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.07)';
  const [searchFocused, setSearchFocused] = React.useState(false);
  const [backHover, setBackHover] = React.useState(false);

  return (
    <div style={{
      height: 52, display: 'flex', alignItems: 'center', gap: 12,
      padding: '0 20px', flexShrink: 0,
      borderBottom: `0.5px solid ${dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)'}`,
    }}>
      {/* Nav buttons */}
      <div style={{ display: 'flex', gap: 4 }}>
        <div
          onClick={canGoBack ? onBack : undefined}
          onMouseEnter={() => setBackHover(true)}
          onMouseLeave={() => setBackHover(false)}
          style={{
            width: 28, height: 28, borderRadius: 6,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: canGoBack && backHover ? navActiveBg : navBg,
            cursor: canGoBack ? 'pointer' : 'default',
            opacity: canGoBack ? 1 : 0.4,
            transition: 'background 0.12s, opacity 0.12s',
          }}>
          <IconChevronLeft size={14} color={mutedColor} />
        </div>
        <div
          onClick={canGoForward ? onForward : undefined}
          style={{
            width: 28, height: 28, borderRadius: 6,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            background: navBg,
            cursor: canGoForward ? 'pointer' : 'default',
            opacity: canGoForward ? 1 : 0.4,
            transition: 'opacity 0.12s',
          }}>
          <IconChevronRight size={14} color={mutedColor} />
        </div>
      </div>

      {/* Title */}
      <h1 style={{
        fontSize: 20, fontWeight: 700, color: textColor,
        margin: 0, letterSpacing: '-0.02em', flex: 1,
      }}>{title}</h1>

      {/* Search */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 6,
        padding: '0 10px', height: 30, borderRadius: 8,
        background: searchFocused ? (dark ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.07)') : searchBg,
        border: `0.5px solid ${searchFocused ? (dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)') : searchBorder}`,
        transition: 'all 0.15s ease', width: searchFocused ? 200 : 160,
      }}>
        <IconSearch size={13} color={iconColor} />
        <input
          type="text"
          placeholder="Поиск"
          onFocus={() => setSearchFocused(true)}
          onBlur={() => setSearchFocused(false)}
          style={{
            border: 'none', outline: 'none', background: 'transparent',
            fontSize: 13, color: textColor, width: '100%',
            fontFamily: 'inherit',
          }}
        />
      </div>
    </div>
  );
}

function CadenceContent({ dark, onAlbumClick }) {
  return (
    <div style={{
      flex: 1, display: 'flex', flexDirection: 'column',
      overflow: 'hidden',
    }}>
      <CadenceToolbar dark={dark} />
      <div style={{
        flex: 1, overflowY: 'auto', overflowX: 'hidden',
        padding: '16px 20px',
      }}>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, 160px)',
          gap: 16, justifyContent: 'start',
        }}>
          {ALBUM_DATA.map(album => (
            <AlbumCard key={album.id} album={album} dark={dark} onClick={() => onAlbumClick && onAlbumClick(album)} />
          ))}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { CadenceContent, CadenceToolbar, AlbumCard, AlbumCover, ALBUM_DATA });
