// cadence-connect.jsx — Server connection window for Cadence

// ── App icon ────────────────────────────────────────────────────────────────

function CadenceAppIcon({ size = 64 }) {
  const r = size * 0.215;
  return (
    <div style={{
      width: size, height: size, borderRadius: r,
      background: 'linear-gradient(145deg, #6B4FBB 0%, #3B7DE8 55%, #2ABFCF 100%)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      boxShadow: '0 6px 22px rgba(59,125,232,0.35), 0 2px 6px rgba(0,0,0,0.12)',
      flexShrink: 0,
    }}>
      <svg width={size * 0.52} height={size * 0.4} viewBox="0 0 36 28" fill="none">
        <rect x="0"  y="18" width="4.5" height="10" rx="2.2" fill="white" opacity="0.65"/>
        <rect x="6.5"  y="9"  width="4.5" height="19" rx="2.2" fill="white"/>
        <rect x="13" y="13" width="4.5" height="15" rx="2.2" fill="white" opacity="0.82"/>
        <rect x="19.5" y="4"  width="4.5" height="24" rx="2.2" fill="white"/>
        <rect x="26" y="11" width="4.5" height="17" rx="2.2" fill="white" opacity="0.82"/>
        <rect x="32" y="16" width="3.5" height="12" rx="1.75" fill="white" opacity="0.55"/>
      </svg>
    </div>
  );
}

// ── Shared input ─────────────────────────────────────────────────────────────

function ConnectInput({ label, value, onChange, placeholder, type = 'text', dark, error, autoFocus }) {
  const [focused, setFocused] = React.useState(false);
  const accent     = dark ? '#0A84FF' : '#007AFF';
  const textColor  = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.86)';
  const labelColor = dark ? 'rgba(255,255,255,0.48)' : 'rgba(0,0,0,0.44)';
  const inputBg    = dark ? 'rgba(255,255,255,0.07)' : '#fff';
  const borderNorm = dark ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.14)';
  const borderFoc  = accent;
  const borderErr  = '#FF3B30';
  const border     = error ? borderErr : (focused ? borderFoc : borderNorm);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
      <label style={{ fontSize: 12, fontWeight: 500, color: labelColor }}>{label}</label>
      <input
        type={type}
        value={value}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
        autoFocus={autoFocus}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        style={{
          height: 34, padding: '0 12px', borderRadius: 8,
          background: inputBg,
          border: `1px solid ${border}`,
          outline: 'none', fontSize: 13, color: textColor,
          fontFamily: 'inherit',
          boxShadow: focused ? `0 0 0 3px ${accent}22` : (error ? '0 0 0 3px rgba(255,59,48,0.18)' : 'none'),
          transition: 'border-color 0.15s, box-shadow 0.15s',
          width: '100%',
        }}
      />
    </div>
  );
}

// ── Auth segmented control ────────────────────────────────────────────────────

function AuthSegmented({ value, onChange, dark }) {
  const accent     = dark ? '#0A84FF' : '#007AFF';
  const trackBg    = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)';
  const textColor  = dark ? 'rgba(255,255,255,0.88)' : 'rgba(0,0,0,0.84)';
  const subColor   = dark ? 'rgba(255,255,255,0.42)' : 'rgba(0,0,0,0.38)';
  const opts = [{ v: 'password', l: 'Логин / Пароль' }, { v: 'apikey', l: 'API Key' }];

  return (
    <div style={{ display: 'flex', background: trackBg, borderRadius: 9, padding: 3, gap: 2 }}>
      {opts.map(o => {
        const sel = o.v === value;
        return (
          <div
            key={o.v}
            onClick={() => onChange(o.v)}
            style={{
              flex: 1, height: 28, borderRadius: 7,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer', userSelect: 'none',
              fontSize: 13, fontWeight: sel ? 600 : 400,
              color: sel ? textColor : subColor,
              background: sel ? (dark ? 'rgba(255,255,255,0.12)' : '#fff') : 'transparent',
              boxShadow: sel ? (dark ? 'none' : '0 1px 4px rgba(0,0,0,0.1)') : 'none',
              transition: 'all 0.15s',
            }}
          >{o.l}</div>
        );
      })}
    </div>
  );
}

// ── Spinner ───────────────────────────────────────────────────────────────────

function ConnectSpinner({ dark, size = 18 }) {
  const accent = dark ? '#0A84FF' : '#007AFF';
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      border: `2.5px solid ${dark ? 'rgba(255,255,255,0.14)' : 'rgba(0,0,0,0.1)'}`,
      borderTopColor: accent,
      animation: 'connectSpin 0.72s linear infinite',
      flexShrink: 0,
    }}></div>
  );
}

// ── Step 1: Form ──────────────────────────────────────────────────────────────

function ConnectFormStep({ dark, authMethod, setAuthMethod, url, setUrl,
  username, setUsername, password, setPassword, apiKey, setApiKey,
  onConnect, onCancel, isChecking, hasError }) {

  const accent     = dark ? '#0A84FF' : '#007AFF';
  const textColor  = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.86)';
  const subColor   = dark ? 'rgba(255,255,255,0.45)' : 'rgba(0,0,0,0.42)';
  const btnSecBg   = dark ? 'rgba(255,255,255,0.09)' : 'rgba(0,0,0,0.05)';
  const btnSecBdr  = dark ? 'rgba(255,255,255,0.1)'  : 'rgba(0,0,0,0.1)';

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 20 }}>
      {/* Icon + headline */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
        <CadenceAppIcon size={64} />
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 18, fontWeight: 700, color: textColor, letterSpacing: '-0.02em', lineHeight: '24px' }}>
            Подключение к Jellyfin
          </div>
          <div style={{ fontSize: 13, color: subColor, marginTop: 4, lineHeight: '18px' }}>
            Введите адрес вашего сервера
          </div>
        </div>
      </div>

      {/* Form */}
      <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 12 }}>
        <ConnectInput
          label="Адрес сервера"
          value={url}
          onChange={setUrl}
          placeholder="https://jellyfin.example.com"
          dark={dark}
          error={hasError}
          autoFocus
        />
        {hasError && (
          <div style={{
            fontSize: 12, color: '#FF3B30', display: 'flex', alignItems: 'center', gap: 6,
            marginTop: -6, animation: 'connectFadeIn 0.2s ease',
          }}>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="10" stroke="#FF3B30" strokeWidth="2"/>
              <path d="M12 7v5M12 16v1" stroke="#FF3B30" strokeWidth="2" strokeLinecap="round"/>
            </svg>
            Не удалось подключиться. Проверьте адрес сервера.
          </div>
        )}

        {/* Auth method */}
        <AuthSegmented value={authMethod} onChange={setAuthMethod} dark={dark} />

        {authMethod === 'password' ? (
          <>
            <ConnectInput label="Имя пользователя" value={username} onChange={setUsername} placeholder="admin" dark={dark} />
            <ConnectInput label="Пароль" value={password} onChange={setPassword} placeholder="••••••••" type="password" dark={dark} />
          </>
        ) : (
          <ConnectInput label="API Key" value={apiKey} onChange={setApiKey} placeholder="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" dark={dark} />
        )}
      </div>

      {/* Actions */}
      <div style={{ display: 'flex', gap: 10, width: '100%' }}>
        <button
          onClick={onCancel}
          style={{
            flex: 1, height: 34, borderRadius: 8, cursor: 'pointer',
            background: btnSecBg, border: `0.5px solid ${btnSecBdr}`,
            color: textColor, fontSize: 13, fontWeight: 500, fontFamily: 'inherit',
          }}
          onMouseEnter={e => e.currentTarget.style.background = dark ? 'rgba(255,255,255,0.13)' : 'rgba(0,0,0,0.08)'}
          onMouseLeave={e => e.currentTarget.style.background = btnSecBg}
        >Отмена</button>
        <button
          onClick={onConnect}
          disabled={isChecking}
          style={{
            flex: 2, height: 34, borderRadius: 8, cursor: isChecking ? 'default' : 'pointer',
            background: accent, border: 'none',
            color: '#fff', fontSize: 13, fontWeight: 600, fontFamily: 'inherit',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            opacity: isChecking ? 0.85 : 1,
            transition: 'filter 0.1s',
          }}
          onMouseEnter={e => { if (!isChecking) e.currentTarget.style.filter = 'brightness(1.1)'; }}
          onMouseLeave={e => e.currentTarget.style.filter = 'brightness(1)'}
        >
          {isChecking && <ConnectSpinner dark={false} size={14} />}
          {isChecking ? 'Подключение...' : 'Подключиться'}
        </button>
      </div>
    </div>
  );
}

// ── Step 2: Success ───────────────────────────────────────────────────────────

function ConnectSuccessStep({ dark, serverName, username, onStart, onClose }) {
  const accent    = dark ? '#0A84FF' : '#007AFF';
  const textColor = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.86)';
  const subColor  = dark ? 'rgba(255,255,255,0.45)' : 'rgba(0,0,0,0.42)';
  const cardBg    = dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.03)';
  const cardBdr   = dark ? 'rgba(255,255,255,0.09)' : 'rgba(0,0,0,0.08)';
  const trackCount = 2847;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 22 }}>
      {/* Checkmark */}
      <div style={{ animation: 'connectScaleIn 0.4s cubic-bezier(0.34,1.56,0.64,1)' }}>
        <svg width="72" height="72" viewBox="0 0 72 72" fill="none">
          <circle cx="36" cy="36" r="36" fill="rgba(52,199,89,0.12)"/>
          <circle cx="36" cy="36" r="29" fill="rgba(52,199,89,0.15)"/>
          <circle cx="36" cy="36" r="22" fill="#34C759"/>
          <path d="M25 36l8 8 14-14" stroke="white" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </div>

      {/* Title */}
      <div style={{ textAlign: 'center', animation: 'connectFadeIn 0.3s 0.2s ease both' }}>
        <div style={{ fontSize: 18, fontWeight: 700, color: textColor, letterSpacing: '-0.02em', lineHeight: '24px' }}>
          Подключено!
        </div>
        <div style={{ fontSize: 13, color: subColor, marginTop: 4, lineHeight: '18px' }}>
          {serverName || 'Домашний медиасервер'}
        </div>
      </div>

      {/* Info card */}
      <div style={{
        width: '100%', borderRadius: 10, padding: '12px 16px',
        background: cardBg, border: `0.5px solid ${cardBdr}`,
        display: 'flex', flexDirection: 'column', gap: 8,
        animation: 'connectFadeIn 0.3s 0.35s ease both',
      }}>
        {[
          ['Пользователь', username || 'admin'],
          ['Треков в библиотеке', trackCount.toLocaleString('ru-RU')],
          ['Статус', 'Онлайн'],
        ].map(([label, value]) => (
          <div key={label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: 12, color: subColor }}>{label}</span>
            <span style={{ fontSize: 13, fontWeight: 500, color: label === 'Статус' ? '#34C759' : textColor }}>
              {value}
            </span>
          </div>
        ))}
      </div>

      {/* Start button */}
      <button
        onClick={onStart}
        style={{
          width: '100%', height: 36, borderRadius: 8, cursor: 'pointer',
          background: accent, border: 'none', color: '#fff',
          fontSize: 14, fontWeight: 600, fontFamily: 'inherit',
          animation: 'connectFadeIn 0.3s 0.45s ease both',
          transition: 'filter 0.1s',
        }}
        onMouseEnter={e => e.currentTarget.style.filter = 'brightness(1.1)'}
        onMouseLeave={e => e.currentTarget.style.filter = 'brightness(1)'}
      >Начать</button>
    </div>
  );
}

// ── Main ConnectWindow ────────────────────────────────────────────────────────

function ConnectWindow({ dark, isOpen, onClose }) {
  const [step,       setStep]       = React.useState('form');
  const [authMethod, setAuthMethod] = React.useState('password');
  const [url,        setUrl]        = React.useState('');
  const [username,   setUsername]   = React.useState('');
  const [password,   setPassword]   = React.useState('');
  const [apiKey,     setApiKey]     = React.useState('');
  const [hasError,   setHasError]   = React.useState(false);

  const isChecking = step === 'checking';

  const handleConnect = () => {
    setHasError(false);
    setStep('checking');
    setTimeout(() => {
      const valid = url.trim().length > 0 && (url.startsWith('http') || url.includes('.'));
      if (valid) { setStep('success'); }
      else       { setStep('form'); setHasError(true); }
    }, 1800);
  };

  const handleClose = () => {
    setStep('form'); setHasError(false);
    setUrl(''); setUsername(''); setPassword(''); setApiKey('');
    onClose();
  };

  if (!isOpen) return null;

  const winBg     = dark ? 'rgba(34,34,38,0.97)' : '#fafafa';
  const borderClr = dark ? 'rgba(255,255,255,0.09)' : 'rgba(0,0,0,0.1)';
  const textColor = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.86)';

  return (
    <div style={{
      position: 'absolute',
      left: (1100 - 420) / 2,
      top: Math.max(40, (700 - (step === 'success' ? 410 : 480)) / 2),
      width: 420, borderRadius: 14,
      background: winBg,
      backdropFilter: 'blur(60px) saturate(200%)',
      WebkitBackdropFilter: 'blur(60px) saturate(200%)',
      boxShadow: dark
        ? '0 0 0 0.5px rgba(255,255,255,0.1), 0 28px 90px rgba(0,0,0,0.7), 0 8px 24px rgba(0,0,0,0.4)'
        : '0 0 0 0.5px rgba(0,0,0,0.12), 0 28px 90px rgba(0,0,0,0.16), 0 8px 24px rgba(0,0,0,0.08)',
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
      zIndex: 400,
      overflow: 'hidden',
      animation: 'connectScaleIn 0.22s cubic-bezier(0.4,0,0.2,1)',
      animationFillMode: 'forwards',
    }}>
      {/* Title bar */}
      <div style={{
        height: 38, display: 'flex', alignItems: 'center', padding: '0 14px',
        background: dark ? 'rgba(0,0,0,0.2)' : 'rgba(0,0,0,0.025)',
        borderBottom: `0.5px solid ${borderClr}`,
      }}>
        <div style={{ display: 'flex', gap: 6 }}>
          <div onClick={handleClose} style={{ width: 11, height: 11, borderRadius: '50%', background: '#FF5F57', cursor: 'pointer', border: '0.5px solid rgba(0,0,0,0.1)' }}></div>
          <div style={{ width: 11, height: 11, borderRadius: '50%', background: '#FEBC2E', border: '0.5px solid rgba(0,0,0,0.1)' }}></div>
          <div style={{ width: 11, height: 11, borderRadius: '50%', background: '#28C840', border: '0.5px solid rgba(0,0,0,0.1)' }}></div>
        </div>
        <div style={{ flex: 1, textAlign: 'center', fontSize: 13, fontWeight: 600, color: textColor, letterSpacing: '-0.015em' }}>
          {step === 'success' ? 'Сервер добавлен' : 'Новый сервер'}
        </div>
        <div style={{ width: 11 * 3 + 6 * 2 }}></div>
      </div>

      {/* Content */}
      <div style={{ padding: '24px 28px 28px' }}>
        {step === 'success' ? (
          <ConnectSuccessStep
            dark={dark}
            username={username || (authMethod === 'apikey' ? 'API Key' : 'admin')}
            onStart={handleClose}
            onClose={handleClose}
          />
        ) : (
          <ConnectFormStep
            dark={dark}
            authMethod={authMethod} setAuthMethod={setAuthMethod}
            url={url} setUrl={setUrl}
            username={username} setUsername={setUsername}
            password={password} setPassword={setPassword}
            apiKey={apiKey} setApiKey={setApiKey}
            onConnect={handleConnect}
            onCancel={handleClose}
            isChecking={isChecking}
            hasError={hasError}
          />
        )}
      </div>
    </div>
  );
}

Object.assign(window, { ConnectWindow, CadenceAppIcon });
