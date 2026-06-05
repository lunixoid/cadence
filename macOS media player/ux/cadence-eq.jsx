// cadence-eq.jsx — Equalizer floating window for Cadence

const EQ_BANDS = ['32', '64', '125', '250', '500', '1K', '2K', '4K', '8K', '16K'];
const EQ_MIN = -12, EQ_MAX = 12;

const EQ_PRESETS = {
  'Flat':        [ 0,  0,  0,  0,  0,  0,  0,  0,  0,  0],
  'Rock':        [ 6,  5,  3,  0, -2, -3, -2,  1,  4,  5],
  'Pop':         [-1,  0,  2,  3,  2,  0, -1, -1,  0,  0],
  'Jazz':        [ 3,  2,  1,  2, -2, -2,  0,  1,  2,  3],
  'Classical':   [ 4,  3,  2,  1, -2, -2,  0,  2,  3,  4],
  'Electronic':  [ 5,  4,  1,  0, -3, -4, -2,  1,  4,  5],
  'Hip-Hop':     [ 5,  4,  1,  1, -2, -2, -1,  1,  2,  1],
  'Acoustic':    [ 3,  2,  2,  1,  1,  0,  0,  1,  1,  2],
  'Bass Boost':  [ 6,  5,  4,  2,  0, -1, -1,  0,  0,  0],
  'Vocal Boost': [-2, -1,  0,  2,  4,  4,  3,  1,  0, -1],
};

const TRACK_H = 150; // px for the slider visual track

function EQSlider({ value, bandLabel, onChange, dark, accent, enabled }) {
  const trackRef = React.useRef(null);
  const dragging = React.useRef(false);

  const pxPerDb = TRACK_H / (EQ_MAX - EQ_MIN);
  const zeroY   = TRACK_H / 2;
  const valueToY = (v) => zeroY - v * pxPerDb;
  const yToValue = (clientY) => {
    if (!trackRef.current) return 0;
    const rect = trackRef.current.getBoundingClientRect();
    const y = clientY - rect.top;
    const clamped = Math.max(0, Math.min(TRACK_H, y));
    return Math.round(Math.max(EQ_MIN, Math.min(EQ_MAX, (zeroY - clamped) / pxPerDb)));
  };

  const startDrag = (e) => {
    e.preventDefault();
    dragging.current = true;
    const move = (ev) => { if (dragging.current) onChange(yToValue(ev.clientY)); };
    const up   = ()   => { dragging.current = false; window.removeEventListener('mousemove', move); window.removeEventListener('mouseup', up); };
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
  };

  const handleY   = valueToY(value);
  const fillTop   = value >= 0 ? handleY : zeroY;
  const fillH     = Math.abs(value) * pxPerDb;

  const trackColor  = dark ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.1)';
  const fillColor   = accent + (enabled ? 'cc' : '66');
  const zeroColor   = dark ? 'rgba(255,255,255,0.28)' : 'rgba(0,0,0,0.18)';
  const labelColor  = dark ? 'rgba(255,255,255,0.42)' : 'rgba(0,0,0,0.38)';
  const dbColor     = value !== 0 ? accent : (dark ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.3)');

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, userSelect: 'none' }}>
      {/* dB value */}
      <span style={{
        fontSize: 10, fontWeight: 600, color: dbColor,
        minWidth: 30, textAlign: 'center',
        fontVariantNumeric: 'tabular-nums', lineHeight: '13px',
        transition: 'color 0.12s',
      }}>
        {value > 0 ? `+${value}` : value}
      </span>

      {/* Track */}
      <div
        ref={trackRef}
        onClick={e => {
          const rect = e.currentTarget.getBoundingClientRect();
          const y = e.clientY - rect.top;
          onChange(Math.round(Math.max(EQ_MIN, Math.min(EQ_MAX, (zeroY - Math.max(0, Math.min(TRACK_H, y))) / pxPerDb))));
        }}
        style={{
          width: 3, height: TRACK_H,
          background: trackColor,
          borderRadius: 2,
          position: 'relative',
          cursor: 'pointer',
          flexShrink: 0,
        }}
      >
        {/* Accent fill */}
        {value !== 0 && (
          <div style={{
            position: 'absolute',
            top: fillTop, left: 0, right: 0,
            height: Math.max(fillH, 1),
            background: fillColor,
            borderRadius: 2,
            transition: 'background 0.15s',
          }}></div>
        )}

        {/* Zero line tick */}
        <div style={{
          position: 'absolute',
          top: zeroY - 0.75, left: -3, right: -3,
          height: 1.5, background: zeroColor, borderRadius: 1,
        }}></div>

        {/* Handle */}
        <div
          onMouseDown={startDrag}
          style={{
            position: 'absolute',
            top: handleY - 7,
            left: '50%', transform: 'translateX(-50%)',
            width: 14, height: 14, borderRadius: '50%',
            background: '#fff',
            border: `2px solid ${accent}`,
            boxShadow: `0 1px 6px rgba(0,0,0,0.22), 0 0 0 1px ${accent}22`,
            cursor: 'grab',
            zIndex: 2,
            transition: 'box-shadow 0.1s',
          }}
          onMouseEnter={e => e.currentTarget.style.boxShadow = `0 2px 8px rgba(0,0,0,0.3), 0 0 0 3px ${accent}33`}
          onMouseLeave={e => e.currentTarget.style.boxShadow = `0 1px 6px rgba(0,0,0,0.22), 0 0 0 1px ${accent}22`}
        ></div>
      </div>

      {/* Frequency label */}
      <span style={{ fontSize: 10, color: labelColor, textAlign: 'center', lineHeight: '13px', letterSpacing: '-0.01em' }}>
        {bandLabel}
      </span>
    </div>
  );
}

function EQWindow({ dark, isOpen, onClose }) {
  const [enabled,  setEnabled]  = React.useState(true);
  const [preset,   setPreset]   = React.useState('Rock');
  const [bands,    setBands]    = React.useState([...EQ_PRESETS['Rock']]);

  const accent      = dark ? '#0A84FF' : '#007AFF';
  const winBg       = dark ? 'rgba(36,36,40,0.97)' : 'rgba(250,250,252,0.97)';
  const borderColor = dark ? 'rgba(255,255,255,0.09)' : 'rgba(0,0,0,0.09)';
  const textColor   = dark ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.86)';
  const subColor    = dark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.36)';
  const inputBg     = dark ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.04)';
  const headerBg    = dark ? 'rgba(0,0,0,0.18)' : 'rgba(0,0,0,0.025)';

  const updateBand = (idx, v) => {
    const next = [...bands];
    next[idx] = v;
    setBands(next);
    const hit = Object.entries(EQ_PRESETS).find(([, vals]) => vals.every((x, i) => x === next[i]));
    setPreset(hit ? hit[0] : 'Custom');
  };

  const applyPreset = (name) => {
    if (!EQ_PRESETS[name]) return;
    setPreset(name);
    setBands([...EQ_PRESETS[name]]);
  };

  const isCustom = preset === 'Custom';

  if (!isOpen) return null;

  return (
    <div style={{
      position: 'absolute',
      bottom: 104, right: 20,
      width: 480, borderRadius: 12,
      background: winBg,
      backdropFilter: 'blur(60px) saturate(200%)',
      WebkitBackdropFilter: 'blur(60px) saturate(200%)',
      boxShadow: dark
        ? '0 0 0 0.5px rgba(255,255,255,0.1), 0 24px 80px rgba(0,0,0,0.65), 0 6px 20px rgba(0,0,0,0.35)'
        : '0 0 0 0.5px rgba(0,0,0,0.13), 0 24px 80px rgba(0,0,0,0.13), 0 6px 20px rgba(0,0,0,0.07)',
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
      zIndex: 200,
      overflow: 'hidden',
      animation: 'eqAppear 0.18s cubic-bezier(0.4,0,0.2,1)',
      animationFillMode: 'forwards',
    }}>

      {/* Title bar */}
      <div style={{
        height: 38, display: 'flex', alignItems: 'center',
        padding: '0 14px', gap: 8,
        background: headerBg,
        borderBottom: `0.5px solid ${borderColor}`,
      }}>
        <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
          <div
            onClick={onClose}
            style={{ width: 11, height: 11, borderRadius: '50%', background: '#FF5F57', cursor: 'pointer', border: '0.5px solid rgba(0,0,0,0.1)' }}
          ></div>
          <div style={{ width: 11, height: 11, borderRadius: '50%', background: '#FEBC2E', border: '0.5px solid rgba(0,0,0,0.1)' }}></div>
          <div style={{ width: 11, height: 11, borderRadius: '50%', background: '#28C840', border: '0.5px solid rgba(0,0,0,0.1)' }}></div>
        </div>
        <div style={{ flex: 1, textAlign: 'center' }}>
          <span style={{ fontSize: 13, fontWeight: 600, letterSpacing: '-0.015em', color: textColor }}>Эквалайзер</span>
        </div>
        {/* Balance spacer */}
        <div style={{ width: 11 * 3 + 6 * 2, flexShrink: 0 }}></div>
      </div>

      {/* Controls row */}
      <div style={{
        height: 44, display: 'flex', alignItems: 'center', gap: 10,
        padding: '0 20px',
        borderBottom: `0.5px solid ${borderColor}`,
      }}>
        {/* On/off toggle */}
        <div
          onClick={() => setEnabled(e => !e)}
          style={{
            width: 38, height: 22, borderRadius: 11,
            background: enabled ? accent : (dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.14)'),
            position: 'relative', cursor: 'pointer', flexShrink: 0,
            transition: 'background 0.2s ease',
            boxShadow: enabled ? `0 0 0 0.5px ${accent}66` : 'none',
          }}
        >
          <div style={{
            position: 'absolute',
            top: 3, left: enabled ? 19 : 3,
            width: 16, height: 16, borderRadius: '50%',
            background: '#fff',
            boxShadow: '0 1px 4px rgba(0,0,0,0.25)',
            transition: 'left 0.18s ease',
          }}></div>
        </div>

        {/* Preset dropdown */}
        <div style={{ flex: 1, position: 'relative' }}>
          <select
            value={preset}
            onChange={e => applyPreset(e.target.value)}
            disabled={!enabled}
            style={{
              width: '100%', height: 28, borderRadius: 6,
              background: inputBg,
              border: `0.5px solid ${borderColor}`,
              color: textColor, fontSize: 13,
              padding: '0 8px',
              outline: 'none', cursor: 'pointer',
              fontFamily: 'inherit',
              opacity: enabled ? 1 : 0.45,
              transition: 'opacity 0.15s',
              WebkitAppearance: 'none', appearance: 'none',
            }}
          >
            {Object.keys(EQ_PRESETS).map(p => (
              <option key={p} value={p} style={{ background: dark ? '#333' : '#fff', color: dark ? '#fff' : '#000' }}>{p}</option>
            ))}
            {isCustom && <option value="Custom" style={{ background: dark ? '#333' : '#fff', color: dark ? '#fff' : '#000' }}>Custom</option>}
          </select>
          {/* Arrow */}
          <div style={{
            position: 'absolute', right: 8, top: '50%', transform: 'translateY(-50%)',
            pointerEvents: 'none', fontSize: 9, color: subColor,
          }}>▾</div>
        </div>

        {/* Save preset — only in Custom */}
        {isCustom && (
          <button style={{
            padding: '0 12px', height: 28, borderRadius: 6,
            background: accent, border: 'none',
            color: '#fff', fontSize: 12, fontWeight: 600,
            fontFamily: 'inherit', cursor: 'pointer', flexShrink: 0,
            transition: 'filter 0.1s',
          }}
          onMouseEnter={e => e.currentTarget.style.filter = 'brightness(1.12)'}
          onMouseLeave={e => e.currentTarget.style.filter = 'brightness(1)'}
          >Сохранить</button>
        )}
      </div>

      {/* Sliders area */}
      <div style={{
        padding: '14px 20px 16px',
        opacity: enabled ? 1 : 0.38,
        transition: 'opacity 0.2s ease',
        pointerEvents: enabled ? 'auto' : 'none',
      }}>
        <div style={{ display: 'flex', gap: 0, alignItems: 'flex-start' }}>
          {/* dB axis labels */}
          <div style={{
            display: 'flex', flexDirection: 'column',
            justifyContent: 'space-between',
            height: TRACK_H + 13, /* track + top label */
            paddingTop: 13,       /* align with top of track (below db label) */
            marginRight: 6,
            flexShrink: 0,
          }}>
            {['+12', '+6', '0', '-6', '-12'].map(l => (
              <span key={l} style={{
                fontSize: 9, color: subColor,
                fontVariantNumeric: 'tabular-nums',
                lineHeight: 1, textAlign: 'right', display: 'block',
                letterSpacing: '-0.01em',
              }}>{l}</span>
            ))}
          </div>

          {/* Sliders */}
          <div style={{ flex: 1, display: 'flex', justifyContent: 'space-between' }}>
            {EQ_BANDS.map((band, i) => (
              <EQSlider
                key={band}
                value={bands[i]}
                bandLabel={band}
                onChange={v => updateBand(i, v)}
                dark={dark}
                accent={accent}
                enabled={enabled}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { EQWindow, EQSlider, EQ_BANDS, EQ_PRESETS });
