// cadence-icons.jsx — SF Symbol-style icons for Cadence

const CadenceIcon = ({ children, size = 16, ...props }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" {...props}>
    {children}
  </svg>
);

// --- Sidebar Icons ---

const IconNowPlaying = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <rect x="3" y="6" width="3" height="12" rx="1.5" fill={color} opacity="0.7"/>
    <rect x="8" y="3" width="3" height="18" rx="1.5" fill={color}/>
    <rect x="13" y="7" width="3" height="10" rx="1.5" fill={color} opacity="0.85"/>
    <rect x="18" y="5" width="3" height="14" rx="1.5" fill={color} opacity="0.6"/>
  </CadenceIcon>
);

const IconMusicNote = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M9 18V5.5l10-2v12" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    <circle cx="6" cy="18" r="3" fill={color}/>
    <circle cx="16" cy="15.5" r="3" fill={color}/>
  </CadenceIcon>
);

const IconAlbum = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <circle cx="12" cy="12" r="9" stroke={color} strokeWidth="2"/>
    <circle cx="12" cy="12" r="3" fill={color}/>
    <circle cx="12" cy="12" r="6" stroke={color} strokeWidth="1" opacity="0.4"/>
  </CadenceIcon>
);

const IconArtist = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <circle cx="12" cy="8" r="4" stroke={color} strokeWidth="2"/>
    <path d="M4 21c0-3.3 3.6-6 8-6s8 2.7 8 6" stroke={color} strokeWidth="2" strokeLinecap="round"/>
  </CadenceIcon>
);

const IconPlaylist = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M4 6h12M4 10h12M4 14h8" stroke={color} strokeWidth="2" strokeLinecap="round"/>
    <circle cx="17" cy="16" r="3" stroke={color} strokeWidth="2"/>
    <path d="M20 16V9" stroke={color} strokeWidth="2" strokeLinecap="round"/>
  </CadenceIcon>
);

const IconHeart = ({ size = 16, color = 'currentColor', filled = false }) => (
  <CadenceIcon size={size}>
    {filled ? (
      <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" fill={color}/>
    ) : (
      <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" stroke={color} strokeWidth="2" fill="none"/>
    )}
  </CadenceIcon>
);

const IconRecent = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <circle cx="12" cy="12" r="9" stroke={color} strokeWidth="2"/>
    <path d="M12 7v5l3 3" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
  </CadenceIcon>
);

const IconDownload = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M12 3v12m0 0l-4-4m4 4l4-4" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M4 17v2a2 2 0 002 2h12a2 2 0 002-2v-2" stroke={color} strokeWidth="2" strokeLinecap="round"/>
  </CadenceIcon>
);

const IconPlus = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M12 5v14M5 12h14" stroke={color} strokeWidth="2" strokeLinecap="round"/>
  </CadenceIcon>
);

// --- Player Icons ---

const IconPlay = ({ size = 20, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M6 4l14 8-14 8V4z" fill={color}/>
  </CadenceIcon>
);

const IconPause = ({ size = 20, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <rect x="5" y="3" width="5" height="18" rx="1" fill={color}/>
    <rect x="14" y="3" width="5" height="18" rx="1" fill={color}/>
  </CadenceIcon>
);

const IconPrevious = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M19 5l-9 7 9 7V5z" fill={color}/>
    <rect x="5" y="5" width="2.5" height="14" rx="1" fill={color}/>
  </CadenceIcon>
);

const IconNext = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M5 5l9 7-9 7V5z" fill={color}/>
    <rect x="16.5" y="5" width="2.5" height="14" rx="1" fill={color}/>
  </CadenceIcon>
);

const IconShuffle = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M18 4l3 3-3 3M18 14l3 3-3 3" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M3 7h3c2 0 3 1 5 5s3 5 5 5h5M21 7h-5c-1.5 0-2.5.5-3.5 2M9.5 15c-1 1.5-2 2-3.5 2H3" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
  </CadenceIcon>
);

const IconRepeat = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M17 2l3 3-3 3" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M3 11V9a4 4 0 014-4h13" stroke={color} strokeWidth="2" strokeLinecap="round"/>
    <path d="M7 22l-3-3 3-3" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M21 13v2a4 4 0 01-4 4H4" stroke={color} strokeWidth="2" strokeLinecap="round"/>
  </CadenceIcon>
);

const IconVolume = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M11 5L6 9H3v6h3l5 4V5z" fill={color}/>
    <path d="M15 9a4 4 0 010 6M18 6a8 8 0 010 12" stroke={color} strokeWidth="2" strokeLinecap="round"/>
  </CadenceIcon>
);

const IconQueue = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M4 6h16M4 10h16M4 14h10" stroke={color} strokeWidth="2" strokeLinecap="round"/>
    <path d="M17 14v6l4-3-4-3z" fill={color}/>
  </CadenceIcon>
);

const IconEqualizer = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M4 21V14M4 10V3M12 21V12M12 8V3M20 21V16M20 12V3" stroke={color} strokeWidth="2" strokeLinecap="round"/>
    <circle cx="4" cy="12" r="2" fill={color}/>
    <circle cx="12" cy="10" r="2" fill={color}/>
    <circle cx="20" cy="14" r="2" fill={color}/>
  </CadenceIcon>
);

const IconSearch = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <circle cx="10.5" cy="10.5" r="6" stroke={color} strokeWidth="2"/>
    <path d="M15 15l5 5" stroke={color} strokeWidth="2" strokeLinecap="round"/>
  </CadenceIcon>
);

const IconChevronLeft = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M15 4l-8 8 8 8" stroke={color} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
  </CadenceIcon>
);

const IconChevronRight = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M9 4l8 8-8 8" stroke={color} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
  </CadenceIcon>
);

const IconVolumeMute = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <path d="M11 5L6 9H3v6h3l5 4V5z" fill={color}/>
    <path d="M16 9l6 6M22 9l-6 6" stroke={color} strokeWidth="2" strokeLinecap="round"/>
  </CadenceIcon>
);

const IconSettings = ({ size = 16, color = 'currentColor' }) => (
  <CadenceIcon size={size}>
    <circle cx="12" cy="12" r="3" stroke={color} strokeWidth="2"/>
    <path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z" stroke={color} strokeWidth="2"/>
  </CadenceIcon>
);

Object.assign(window, {
  IconNowPlaying, IconMusicNote, IconAlbum, IconArtist,
  IconPlaylist, IconHeart, IconRecent, IconDownload, IconPlus,
  IconPlay, IconPause, IconPrevious, IconNext, IconShuffle, IconRepeat,
  IconVolume, IconVolumeMute, IconQueue, IconEqualizer, IconSearch,
  IconChevronLeft, IconChevronRight, IconSettings,
});
