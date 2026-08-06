# Design plan — Cadence (онбординг ДС)

## Предмет
Cadence — нативный macOS audio player (библиотека, Now Playing, очередь, EQ, настройки, подключение к серверу). Аудитория: пользователи локальной/серверной музыки на Mac.

## Палитра
Dual theme Apple HIG:
- Accent: `#007AFF` (light) / `#0A84FF` (dark)
- Window: `#ffffff` / `#282828`
- Content: `#f5f5f7` / `#1e1e20`
- Sidebar glass: `rgba(245,245,247,0.72)` / `rgba(40,40,45,0.82)`
- Text primary ~0.85–0.92 opacity; secondary ~0.40–0.50; muted ~0.28–0.35
- Danger `#FF3B30`, Favorites `#FF375F`, Success `#34C759` / `#1A9A3C`
- Traffic lights: `#FF5F57` / `#FEBC2E` / `#28C840`

## Типографика
Единое семейство system UI: `-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif`.  
Display = тот же стек, weight 700; body 400–500; captions/section labels 11px / 700 / uppercase или letter-spacing.

## Layout
Окно 1100×700, radius 12. Sidebar 220 (full height) | content + Now Playing bar. Hairline 0.5px разделители. Отступы кратны 4/8.

## Signature
Vinyl-обложки (квадрат + «диск» в центре) + frosted glass sidebar (`blur(50px) saturate(180%)`) + system-blue progress/play. Один акцент на экране.

## Полотно
App window: **1100×700**. Эталоны ДС: 1100×700 или компактные карточки внутри.

## Антипаттерны
- Не web-SaaS: карточки с левой цветной полосой, фиолетовые градиенты, Inter/Roboto
- Не cream+serif, не brutalist hairline-газеты
- Не emoji вместо SF-символов/SVG-иконок
- Не менять system blue на «брендовый» фиолетовый/неоновый
- Не плоские inset hero-карточки вместо macOS window chrome
- Hover не делает текст серее/светлее primary — усиливает фон или контраст иконки

## Самокритика
System UI + Apple blue — осознанный macOS-лук продукта, не ИИ-дефолт. Отличие — vinyl covers + liquid-glass sidebar, не новая палитра.
