// cadence-prefs.jsx — Preferences window for Cadence (always light theme)

// ── Tab icons (inline SVG) ──────────────────────────────────────────────────

const PrefIconServer = ({ size = 22, color = 'currentColor' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <rect x="2" y="4" width="20" height="5.5" rx="1.5" stroke={color} strokeWidth="1.6"/>
    <rect x="2" y="11.5" width="20" height="5.5" rx="1.5" stroke={color} strokeWidth="1.6"/>
    <circle cx="19" cy="6.75" r="1.1" fill={color}/>
    <circle cx="19" cy="14.25" r="1.1" fill={color}/>
    <circle cx="16" cy="6.75" r="1.1" fill={color}/>
    <circle cx="16" cy="14.25" r="1.1" fill={color}/>
  </svg>
);

const PrefIconPlayback = ({ size = 22, color = 'currentColor' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="9.5" stroke={color} strokeWidth="1.6"/>
    <path d="M10 8.5l6 3.5-6 3.5V8.5z" fill={color}/>
  </svg>
);

const PrefIconCache = ({ size = 22, color = 'currentColor' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <rect x="3" y="4" width="18" height="16" rx="2" stroke={color} strokeWidth="1.6"/>
    <path d="M3 9h18" stroke={color} strokeWidth="1.4"/>
    <circle cx="7" cy="6.5" r="1" fill={color}/>
    <circle cx="10.5" cy="6.5" r="1" fill={color}/>
    <path d="M7 13h4M7 16h7" stroke={color} strokeWidth="1.4" strokeLinecap="round"/>
  </svg>
);

const PrefIconAppearance = ({ size = 22, color = 'currentColor' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
    <path d="M12 2a10 10 0 100 20A10 10 0 0012 2z" stroke={color} strokeWidth="1.6"/>
    <path d="M12 2v20M2 12h10" stroke={color} strokeWidth="1.4"/>
    <path d="M5.6 5.6l4.9 4.9M5.6 18.4l4.9-4.9" stroke={color} strokeWidth="1.3" strokeLinecap="round"/>
  </svg>
);

// ── Shared styled primitives ────────────────────────────────────────────────

const P_TEXT    = 'rgba(0,0,0,0.86)';
const P_SUB     = 'rgba(0,0,0,0.42)';
const P_MUTED   = 'rgba(0,0,0,0.28)';
const P_BORDER  = 'rgba(0,0,0,0.1)';
const P_BG      = 'rgba(0,0,0,0.035)';
const P_HOVER   = 'rgba(0,0,0,0.05)';
const P_ACCENT  = '#007AFF';
const P_SEL_BG  = 'rgba(0,122,255,0.09)';

function PRow({ label, children }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, minHeight: 32 }}>
      <span style={{ width: 160, textAlign: 'right', fontSize: 13, color: P_TEXT, flexShrink: 0 }}>
        {label}
      </span>
      <div style={{ flex: 1 }}>{children}</div>
    </div>
  );
}

function PSelect({ value, options, onChange, width = 220 }) {
  return (
    <div style={{ position: 'relative', width }}>
      <select
        value={value} onChange={e => onChange(e.target.value)}
        style={{
          width: '100%', height: 26, borderRadius: 6,
          background: '#fff',
          border: `0.5px solid ${P_BORDER}`,
          color: P_TEXT, fontSize: 13,
          padding: '0 24px 0 8px',
          outline: 'none', cursor: 'pointer',
          fontFamily: 'inherit',
          WebkitAppearance: 'none', appearance: 'none',
          boxShadow: '0 1px 2px rgba(0,0,0,0.06)',
        }}
      >
        {options.map(o => (
          <option key={o.value ?? o} value={o.value ?? o}>{o.label ?? o}</option>
        ))}
      </select>
      <span style={{ position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)', fontSize: 9, color: P_SUB, pointerEvents: 'none' }}>▾</span>
    </div>
  );
}

function PToggle({ value, onChange }) {
  return (
    <div
      onClick={() => onChange(!value)}
      style={{
        width: 36, height: 20, borderRadius: 10,
        background: value ? P_ACCENT : 'rgba(0,0,0,0.16)',
        position: 'relative', cursor: 'pointer', flexShrink: 0,
        transition: 'background 0.18s',
        boxShadow: value ? `0 0 0 0.5px ${P_ACCENT}44` : 'none',
      }}
    >
      <div style={{
        position: 'absolute', top: 2, left: value ? 18 : 2,
        width: 16, height: 16, borderRadius: '50%', background: '#fff',
        boxShadow: '0 1px 3px rgba(0,0,0,0.22)',
        transition: 'left 0.18s ease',
      }}></div>
    </div>
  );
}

function PSlider({ value, min, max, onChange, unit = '' }) {
  const [hover, setHover] = React.useState(false);
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <div
        onMouseEnter={() => setHover(true)}
        onMouseLeave={() => setHover(false)}
        onClick={e => {
          const rect = e.currentTarget.getBoundingClientRect();
          const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
          onChange(Math.round(min + ratio * (max - min)));
        }}
        style={{ width: 180, height: 20, display: 'flex', alignItems: 'center', cursor: 'pointer' }}
      >
        <div style={{ width: '100%', height: hover ? 5 : 3, borderRadius: 3, background: 'rgba(0,0,0,0.1)', position: 'relative', transition: 'height 0.12s' }}>
          <div style={{ height: '100%', width: `${pct}%`, borderRadius: 3, background: P_ACCENT }}>
            {hover && <div style={{ position: 'absolute', right: -6, top: '50%', transform: 'translateY(-50%)', width: 12, height: 12, borderRadius: '50%', background: '#fff', border: `2px solid ${P_ACCENT}`, boxShadow: '0 1px 4px rgba(0,0,0,0.2)' }}></div>}
          </div>
        </div>
      </div>
      <span style={{ fontSize: 12, color: P_SUB, minWidth: 40, fontVariantNumeric: 'tabular-nums' }}>{value}{unit}</span>
    </div>
  );
}

function PDivider() {
  return <div style={{ height: 1, background: P_BORDER, margin: '16px 0' }}></div>;
}

function PLabel({ children }) {
  return (
    <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.05em', color: P_MUTED, marginBottom: 8, marginTop: 4 }}>
      {children}
    </div>
  );
}

// ── Tab: Серверы ────────────────────────────────────────────────────────────

const INIT_SERVERS = [
  { id: 's1', name: 'Домашний медиасервер', url: 'http://192.168.1.100:8096', status: 'online',  active: true,  user: 'admin',  auth: 'API Key'  },
  { id: 's2', name: 'Дача',                 url: 'http://192.168.2.50:8096',  status: 'offline', active: false, user: 'alexey', auth: 'Пароль'   },
];

function TabServers({ onAddServer }) {
  const [servers,  setServers]  = React.useState(INIT_SERVERS);
  const [selId,    setSelId]    = React.useState('s1');
  const sel = servers.find(s => s.id === selId);

  const StatusBadge = ({ status }) => (
    <span style={{
      fontSize: 10, fontWeight: 600, padding: '2px 7px', borderRadius: 4,
      background: status === 'online' ? 'rgba(52,199,89,0.12)' : 'rgba(0,0,0,0.06)',
      color:      status === 'online' ? '#1A9A3C'              : P_MUTED,
    }}>{status === 'online' ? 'Онлайн' : 'Офлайн'}</span>
  );

  return (
    <div style={{ display: 'flex', gap: 20, height: '100%' }}>
      {/* Server list */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        <div style={{ border: `0.5px solid ${P_BORDER}`, borderRadius: 8, overflow: 'hidden', background: '#fff', flex: 1 }}>
          {/* Header */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 70px', padding: '5px 12px', borderBottom: `0.5px solid ${P_BORDER}`, fontSize: 10, fontWeight: 700, color: P_MUTED, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            <span>Название</span><span>URL</span><span>Статус</span>
          </div>
          {servers.map(srv => (
            <div
              key={srv.id}
              onClick={() => setSelId(srv.id)}
              style={{
                display: 'grid', gridTemplateColumns: '1fr 1fr 70px',
                padding: '9px 12px', cursor: 'pointer', alignItems: 'center',
                background: selId === srv.id ? P_SEL_BG : 'transparent',
                borderBottom: `0.5px solid ${P_BORDER}`,
                transition: 'background 0.1s',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 7, minWidth: 0 }}>
                {srv.active && <div style={{ width: 6, height: 6, borderRadius: '50%', background: P_ACCENT, flexShrink: 0 }}></div>}
                <span style={{ fontSize: 13, color: P_TEXT, fontWeight: srv.active ? 600 : 400, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{srv.name}</span>
              </div>
              <span style={{ fontSize: 11, color: P_SUB, fontFamily: 'SF Mono, Menlo, monospace', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', paddingRight: 8 }}>{srv.url}</span>
              <StatusBadge status={srv.status} />
            </div>
          ))}
        </div>

        {/* + − buttons */}
        <div style={{ display: 'flex', marginTop: 6, border: `0.5px solid ${P_BORDER}`, borderRadius: 6, overflow: 'hidden', width: 'fit-content', background: '#fff' }}>
          {['+', '−'].map((ch, i) => (
            <button key={ch} onClick={i === 0 ? onAddServer : undefined} style={{
              width: 28, height: 22, background: 'transparent', border: 'none', cursor: 'pointer',
              fontSize: 15, color: i === 1 ? P_MUTED : P_TEXT, fontFamily: 'inherit',
              borderRight: i === 0 ? `0.5px solid ${P_BORDER}` : 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'center', lineHeight: 1,
            }}>{ch}</button>
          ))}
        </div>
      </div>

      {/* Detail panel */}
      {sel && (
        <div style={{ width: 190, display: 'flex', flexDirection: 'column', gap: 14, paddingTop: 2 }}>
          <span style={{ fontSize: 14, fontWeight: 700, color: P_TEXT, letterSpacing: '-0.01em' }}>{sel.name}</span>
          {[['URL', sel.url, true], ['Пользователь', sel.user, false], ['Авторизация', sel.auth, false]].map(([lbl, val, mono]) => (
            <div key={lbl} style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              <span style={{ fontSize: 10, fontWeight: 700, color: P_MUTED, textTransform: 'uppercase', letterSpacing: '0.05em' }}>{lbl}</span>
              <span style={{ fontSize: 12, color: P_TEXT, wordBreak: 'break-all', fontFamily: mono ? 'SF Mono, Menlo, monospace' : 'inherit' }}>{val}</span>
            </div>
          ))}
          <button
            style={{ padding: '5px 12px', borderRadius: 6, background: P_ACCENT, border: 'none', color: '#fff', fontSize: 12, fontWeight: 600, fontFamily: 'inherit', cursor: 'pointer', alignSelf: 'flex-start', marginTop: 4 }}
            onMouseEnter={e => e.currentTarget.style.filter = 'brightness(1.1)'}
            onMouseLeave={e => e.currentTarget.style.filter = 'brightness(1)'}
          >Проверить связь</button>
        </div>
      )}
    </div>
  );
}

// ── Tab: Воспроизведение ────────────────────────────────────────────────────

function TabPlayback() {
  const [device,   setDevice]   = React.useState('MacBook Pro Speakers');
  const [volume,   setVolume]   = React.useState(80);
  const [gapless,  setGapless]  = React.useState(true);
  const [crossfade, setCrossfade] = React.useState(false);
  const [fadeLen,  setFadeLen]  = React.useState(3);

  const DEVICES = ['MacBook Pro Speakers', 'AirPods Pro', 'Внешние наушники', 'HDMI Output'];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <PLabel>Аудио-устройство</PLabel>
      <PRow label="Вывод звука"><PSelect value={device} options={DEVICES} onChange={setDevice} /></PRow>
      <PRow label="Громкость по умолчанию"><PSlider value={volume} min={0} max={100} onChange={setVolume} unit="%" /></PRow>
      <PDivider />
      <PLabel>Воспроизведение</PLabel>
      <PRow label="Бесшовное воспроизведение"><PToggle value={gapless} onChange={setGapless} /></PRow>
      <PRow label="Кроссфейд"><PToggle value={crossfade} onChange={setCrossfade} /></PRow>
      {crossfade && (
        <PRow label="Длина кроссфейда"><PSlider value={fadeLen} min={1} max={12} onChange={setFadeLen} unit=" с" /></PRow>
      )}
    </div>
  );
}

// ── Tab: Кеш ───────────────────────────────────────────────────────────────

const DOWNLOADED = [
  { id: 'd1', name: 'Midnight Echoes', artist: 'Luna Solaris', size: '124 МБ', colors: ALBUM_DATA[0].colors },
  { id: 'd2', name: 'Static Dreams',   artist: 'Neon Drift',   size: '98 МБ',  colors: ALBUM_DATA[2].colors },
  { id: 'd3', name: 'Облака',          artist: 'Виктория Ши',  size: '87 МБ',  colors: ALBUM_DATA[7].colors },
];

function TabCache() {
  const [cacheLimit, setCacheLimit] = React.useState(10);
  const [downloads,  setDownloads]  = React.useState(DOWNLOADED);
  const usedGb = 2.4;
  const pct    = (usedGb / cacheLimit) * 100;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      {/* Usage bar */}
      <div style={{ marginLeft: 172, marginTop: 2 }}>
        <div style={{ width: 220, height: 6, borderRadius: 3, background: 'rgba(0,0,0,0.08)', overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${Math.min(100, pct)}%`, borderRadius: 3, background: pct > 80 ? '#FF9500' : P_ACCENT, transition: 'width 0.3s' }}></div>
        </div>
        <span style={{ fontSize: 11, color: P_MUTED, marginTop: 4, display: 'block' }}>{usedGb} ГБ занято из {cacheLimit} ГБ</span>
      </div>

      <div style={{ marginLeft: 172, marginTop: 4 }}>
        <button
          style={{ padding: '4px 12px', borderRadius: 6, background: '#fff', border: `0.5px solid ${P_BORDER}`, color: P_TEXT, fontSize: 12, fontWeight: 500, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 1px 2px rgba(0,0,0,0.06)' }}
          onMouseEnter={e => e.currentTarget.style.background = P_HOVER}
          onMouseLeave={e => e.currentTarget.style.background = '#fff'}
        >Очистить кеш</button>
      </div>

      <PDivider />
      <PLabel>Скачанное</PLabel>

      <div style={{ border: `0.5px solid ${P_BORDER}`, borderRadius: 8, overflow: 'hidden', background: '#fff' }}>
        {downloads.map((dl, i) => {
          const [h, setH] = React.useState(false);
          return (
            <div
              key={dl.id}
              onMouseEnter={() => setH(true)}
              onMouseLeave={() => setH(false)}
              style={{
                display: 'flex', alignItems: 'center', gap: 10, padding: '8px 12px',
                borderBottom: i < downloads.length - 1 ? `0.5px solid ${P_BORDER}` : 'none',
                background: h ? P_HOVER : 'transparent', transition: 'background 0.1s',
              }}
            >
              {/* Mini cover */}
              <div style={{ width: 32, height: 32, borderRadius: 5, background: `linear-gradient(135deg,${dl.colors[0]},${dl.colors[1]},${dl.colors[2]})`, flexShrink: 0 }}></div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 500, color: P_TEXT, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{dl.name}</div>
                <div style={{ fontSize: 11, color: P_SUB }}>{dl.artist}</div>
              </div>
              <span style={{ fontSize: 11, color: P_MUTED, flexShrink: 0 }}>{dl.size}</span>
              <div
                onClick={() => setDownloads(p => p.filter(x => x.id !== dl.id))}
                style={{ width: 18, height: 18, borderRadius: '50%', background: h ? 'rgba(0,0,0,0.08)' : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', fontSize: 12, color: P_MUTED, lineHeight: 1, opacity: h ? 1 : 0, transition: 'opacity 0.12s', flexShrink: 0 }}
              >×</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── Tab: Внешний вид ────────────────────────────────────────────────────────

function TabAppearance({ appTheme, onThemeChange }) {
  const themes = [
    { value: 'system', label: 'Системная' },
    { value: 'light',  label: 'Светлая'   },
    { value: 'dark',   label: 'Тёмная'    },
  ];
  const [sidebarStyle, setSidebarStyle] = React.useState('default');
  const [artSize, setArtSize] = React.useState(160);

  const SegButton = ({ value, current, label, onSelect }) => {
    const sel = value === current;
    return (
      <div
        onClick={() => onSelect(value)}
        style={{
          padding: '4px 14px', borderRadius: 5, cursor: 'pointer', fontSize: 13, fontWeight: sel ? 600 : 400,
          background: sel ? '#fff' : 'transparent',
          color: sel ? P_TEXT : P_SUB,
          boxShadow: sel ? '0 1px 4px rgba(0,0,0,0.1)' : 'none',
          transition: 'all 0.15s', userSelect: 'none',
        }}
      >{label}</div>
    );
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <PLabel>Тема оформления</PLabel>
      <PRow label="Тема">
        <div style={{ display: 'flex', background: 'rgba(0,0,0,0.07)', borderRadius: 8, padding: 3, gap: 2 }}>
          {themes.map(t => (
            <SegButton key={t.value} value={t.value} current={appTheme} label={t.label} onSelect={onThemeChange} />
          ))}
        </div>
      </PRow>


    </div>
  );
}

// ── Main PrefsWindow ────────────────────────────────────────────────────────

const PREF_TABS = [
  { id: 'servers',    label: 'Серверы',           Icon: PrefIconServer     },
  { id: 'playback',   label: 'Воспроизведение',   Icon: PrefIconPlayback   },
  { id: 'cache',      label: 'Кеш',               Icon: PrefIconCache      },
  { id: 'appearance', label: 'Внешний вид',        Icon: PrefIconAppearance },
];

function PrefsWindow({ isOpen, onClose, appTheme, onThemeChange, onAddServer }) {
  const [activeTab, setActiveTab] = React.useState('servers');
  if (!isOpen) return null;

  // Always light
  const winBg      = '#f6f6f8';
  const toolbarBg  = 'rgba(240,240,244,0.97)';
  const borderColor = 'rgba(0,0,0,0.1)';
  const contentBg  = '#ffffff';

  const tabContent = {
    servers:    <TabServers onAddServer={onAddServer} />,
    playback:   <TabPlayback />,
    cache:      <TabCache />,
    appearance: <TabAppearance appTheme={appTheme} onThemeChange={onThemeChange} />,
  };

  // Centred over the 1100×700 window
  return (
    <div style={{
      position: 'absolute',
      left: (1100 - 560) / 2, top: (700 - 460) / 2,
      width: 560, borderRadius: 12,
      background: winBg,
      boxShadow: '0 0 0 0.5px rgba(0,0,0,0.13), 0 28px 90px rgba(0,0,0,0.22), 0 8px 24px rgba(0,0,0,0.1)',
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
      zIndex: 300,
      overflow: 'hidden',
      animation: 'eqAppear 0.2s cubic-bezier(0.4,0,0.2,1)',
      animationFillMode: 'forwards',
    }}>

      {/* Title bar */}
      <div style={{
        height: 40, display: 'flex', alignItems: 'center', padding: '0 14px',
        background: toolbarBg, borderBottom: `0.5px solid ${borderColor}`,
      }}>
        <div style={{ display: 'flex', gap: 6 }}>
          <div onClick={onClose} style={{ width: 11, height: 11, borderRadius: '50%', background: '#FF5F57', cursor: 'pointer', border: '0.5px solid rgba(0,0,0,0.1)' }}></div>
          <div style={{ width: 11, height: 11, borderRadius: '50%', background: '#FEBC2E', border: '0.5px solid rgba(0,0,0,0.1)' }}></div>
          <div style={{ width: 11, height: 11, borderRadius: '50%', background: '#28C840', border: '0.5px solid rgba(0,0,0,0.1)' }}></div>
        </div>
        <div style={{ flex: 1, textAlign: 'center', fontSize: 13, fontWeight: 600, color: 'rgba(0,0,0,0.85)', letterSpacing: '-0.015em' }}>
          Настройки
        </div>
        <div style={{ width: 11 * 3 + 6 * 2 }}></div>
      </div>

      {/* Tab toolbar */}
      <div style={{
        display: 'flex', justifyContent: 'center', gap: 0,
        background: toolbarBg, borderBottom: `0.5px solid ${borderColor}`,
        padding: '8px 24px 0',
      }}>
        {PREF_TABS.map(({ id, label, Icon }) => {
          const sel = activeTab === id;
          return (
            <div
              key={id}
              onClick={() => setActiveTab(id)}
              style={{
                display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
                padding: '6px 14px 8px', cursor: 'pointer', minWidth: 80,
                borderBottom: sel ? `2px solid ${P_ACCENT}` : '2px solid transparent',
                color: sel ? P_ACCENT : P_SUB,
                transition: 'color 0.12s, border-color 0.12s',
              }}
              onMouseEnter={e => { if (!sel) e.currentTarget.style.color = 'rgba(0,0,0,0.65)'; }}
              onMouseLeave={e => { if (!sel) e.currentTarget.style.color = P_SUB; }}
            >
              <Icon size={22} color="currentColor" />
              <span style={{ fontSize: 11, fontWeight: sel ? 600 : 400, letterSpacing: '-0.01em', lineHeight: 1 }}>
                {label}
              </span>
            </div>
          );
        })}
      </div>

      {/* Tab content */}
      <div style={{ padding: '20px 24px 24px', background: contentBg, minHeight: 320 }}>
        {tabContent[activeTab]}
      </div>
    </div>
  );
}

Object.assign(window, { PrefsWindow });
