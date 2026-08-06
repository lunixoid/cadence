# Дизайн-система: Cadence (macOS Audio Player)

Режим: приложение (desktop macOS)
Назначение: нативный аудиоплеер для библиотеки и стриминга с сервера; макеты → handoff в Swift/AppKit или дальнейшие HTML-прототипы.

Источник истины извлечён из живого прототипа `Cadence.html` + `cadence-*.jsx`. Не выдумывать новые hex.

## Формат полотна
- App window: **1100×700** (основное полотно макетов)
- Радиус окна: **12px**
- Sidebar width: **220px** (default)
- Фон сцены (за окном): light `#c8cdd3` + radial; dark `#1a1a1c` + radial
- Эталоны ДС: artboard 1100×700 или компактный внутри stage

## Палитра (только эти роли)

### Accent & semantic
| Роль | Light | Dark |
|------|-------|------|
| Accent | `#007AFF` | `#0A84FF` |
| Danger | `#FF3B30` | `#FF3B30` |
| Favorites | `#FF375F` | `#FF375F` |
| Success | `#34C759` / text `#1A9A3C` | то же |
| Traffic close / min / zoom | `#FF5F57` / `#FEBC2E` / `#28C840` | то же |

### Surfaces
| Роль | Light | Dark |
|------|-------|------|
| Window | `#ffffff` | `#282828` |
| Content | `#f5f5f7` | `#1e1e20` |
| Sidebar glass | `rgba(245,245,247,0.72)` | `rgba(40,40,45,0.82)` |
| Player bar | `rgba(252,252,253,0.97)` | `rgba(28,28,30,0.97)` |
| Prefs window | `#f2f2f5` | `#2c2c2e` |
| Prefs card | `#ffffff` | `#3a3a3c` |
| Menu / popover | `rgba(255,255,255,0.96)` | `rgba(50,50,54,0.96)` |

### Text (opacity on black/white)
| Роль | Light | Dark |
|------|-------|------|
| Primary | `rgba(0,0,0,0.85–0.92)` | `rgba(255,255,255,0.85–0.92)` |
| Secondary | `rgba(0,0,0,0.42–0.50)` | `rgba(255,255,255,0.45–0.55)` |
| Muted / section | `rgba(0,0,0,0.28–0.40)` | `rgba(255,255,255,0.28–0.40)` |
| Icon idle | `rgba(0,0,0,0.45–0.55)` | `rgba(255,255,255,0.55–0.70)` |

### Borders & fills
- Hairline: `0.5px solid` → light `rgba(0,0,0,0.08)`, dark `rgba(255,255,255,0.08)`
- Hover fill: light `rgba(0,0,0,0.05–0.06)`, dark `rgba(255,255,255,0.08)`
- Selected row: light `rgba(0,0,0,0.09)`, dark `rgba(255,255,255,0.12)`
- Accent selection (prefs): light `rgba(0,122,255,0.09)`, dark `rgba(10,132,255,0.18)`
- Track/slider rail: light `rgba(0,0,0,0.10)`, dark `rgba(255,255,255,0.13)`

Акцент на экране — **не чаще двух раз** (типично: progress fill + play или selected icon).

## Типографика
- Stack: `-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif`
- Display / title (content H1): 20–26px, weight **700**, tracking ≈ `-0.025em`
- Nav / row: 13px, weight 400; selected **600**
- Meta / artist: 11–12px, weight 400
- Section label (sidebar): 11px, weight **700**, letter-spacing `0.02em`, muted
- Uppercase section (Now Playing): 11px, weight **700**, letter-spacing `0.06em`
- Time / numeric: `font-variant-numeric: tabular-nums`, 11–12px
- Mono не обязателен; tabular-nums достаточно для таймкодов

## Signature
1. **Vinyl cover** — квадратная обложка radius 8–14 + полупрозрачный «диск» по центру  
2. **Frosted sidebar** — `backdrop-filter: blur(50px) saturate(180%)`  
3. **System-blue transport** — круглый play + accent progress  

Один визуальный «крючок» на макет; не добавлять неон/glow поверх.

## Компоненты (app)

### Window chrome
- Radius 12; shadow light: `0 0 0 0.5px rgba(0,0,0,0.15), 0 24px 80px rgba(0,0,0,0.2), 0 8px 24px rgba(0,0,0,0.08)`  
- Dark: `0 0 0 0.5px rgba(255,255,255,0.1), 0 24px 80px rgba(0,0,0,0.65), 0 8px 24px rgba(0,0,0,0.4)`  
- Traffic lights: 12×12, gap 8, в зоне titlebar height 52

### Sidebar nav item
- Height ~28–32, padding horizontal 10–12, radius **6**
- Selected: selectedBg + text primary + accent icon
- Favorites icon active: `#FF375F`

### Search field
- Height 30, radius 8, fill searchBg, border 0.5px

### Album tile
- Cover radius 8; tile hover padding 6, outer radius 10
- Title 12/500, artist 11/400

### Now Playing bar
- Height ~64–72; cover 56×56 radius 8
- Play button 56 круглый: light fill `#1c1c1e` + white icon; dark fill `#ffffff` + `#1c1c1e` icon
- Progress height 4 (hover 6), thumb 14 circle accent
- **Оффлайн (FEAT5):** icon-кнопка рядом с избранным (♥) в meta-блоке; на экране «Сейчас играет» — в ряду действий, бар свёрнут в strip. Состояния: download / ring progress / filled (удалить) / retry (danger). Не второй accent CTA.

### Buttons / controls
- Icon hit target ≥ 28–44
- Segmented / toggle: radius 6–10; switch track 36×20, thumb 16
- Context menu: radius 8, item radius 4; danger hover = `#FF3B30` fill + white text

### Floating windows (EQ, Prefs, Connect)
- Отдельные окна поверх; prefs WIN_BG / CARD из палитры выше

## Линии и формы
- Разделители только **0.5px** hairline
- Радиусы: 4 (menu item), 6 (nav/control), 8 (covers/menus), 10 (tiles), 12 (window), 14 (large NP cover)
- Скроллбар: 7px, thumb `rgba(128,128,128,0.3)`, radius 4
- Без multi-layer цветных glow; тени — нейтральные чёрные с низкой opacity

## Антипаттерны
- Inter / Roboto / Arial как display; cream `#F4F1EA` + serif; purple-to-indigo wash
- Карточки с цветной полосой слева; emoji-иконки; hand-drawn SVG-человечки
- Hover, делающий текст `--muted` или светлее фона
- Второй solid primary CTA на тот же экран
- Смена accent на не-system blue без явного запроса
- Ломать пропорции окна 1100×700 без причины

## Экраны
См. `screens.md`. Живой интерактивный референс: `Cadence.html`.

## Handoff
- Сетка: **4 / 8px**
- Целевой стек: Swift / AppKit (macOS); прототипы — HTML + токены
- Иконки: SF Symbols / существующие `cadence-icons.jsx` SVG
- Тема: light/dark обязательны для новых экранов, если не сказано иначе

## Технически
- Токены: `design-system/tokens.css`
- Эталоны: `design-system/Цвета.html`, `Типографика.html`, `Линии и формы.html`
- План: `design-system/plan.md`
- Макеты: `Экран — <имя>.html` в корне проекта
- В макетах только `var(--*)` из tokens.css; dual theme через `[data-theme="dark"]` на `.artboard` или `html`
