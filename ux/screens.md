# Экраны Cadence

Карта экранов для HTML-макетов. Живой интерактивный референс: `Cadence.html` (macOS), `Экран — iOS Cadence.html` (iPhone 13 Pro).

## macOS

| ID | Экран | Файл макета | Статус | Примечание |
|----|--------|-------------|--------|------------|
| lib | Библиотека (альбомы) | `Экран — библиотека.html` | демо ДС | сетка альбомов + sidebar + player |
| album | Страница альбома | — | в прототипе | `cadence-album-page.jsx` |
| np | Сейчас играет | — | в прототипе | `cadence-nowplaying.jsx` |
| queue | Очередь (панель) | — | в прототипе | `cadence-queue.jsx` |
| eq | Эквалайзер (окно) | — | в прототипе | `cadence-eq.jsx` |
| prefs | Настройки | — | в прототипе | `cadence-prefs.jsx` |
| offline-prefs | Настройки · Кеш / Оффлайн (FEAT5) | `Экран — настройки, оффлайн.html` | макет | 3 состояния × light/dark; кеш ≠ оффлайн |
| offline-menu | Контекстное меню трека · Оффлайн (FEAT5) | `Экран — контекстное меню трека, оффлайн.html` | макет | 4 пункта оффлайна × light/dark |
| offline-player | Player bar · кнопка оффлайна (FEAT5) | `Экран — player bar, оффлайн.html` | макет | рядом с ♥; 4 состояния; не на экране NP |
| offline-np | Сейчас играет · кнопка оффлайна (FEAT5) | `Экран — сейчас играет, оффлайн.html` | макет | в ряду действий; бар свёрнут в strip |
| connect | Подключение к серверу | — | в прототипе | `cadence-connect.jsx` |
| artists | Артисты | — | nav есть | контент TBD |
| tracks | Все треки | — | nav есть | контент TBD |
| favorites | Избранное | — | nav есть | accent `#FF375F` |
| playlists | Плейлист | — | sidebar | контекстное меню delete |

## iOS (iPhone 13 Pro · 390×844)

| ID | Экран | Файл / маршрут | Статус | Примечание |
|----|--------|----------------|--------|------------|
| ios-shell | Интерактивный плеер | `Экран — iOS Cadence.html` / `CadenceiOS` | Swift | Light+Dark; табы + sheets |
| ios-lib | Вкладка Библиотека | `#library` / `IOSLibraryView` | Swift | сегменты Все треки / Альбомы / Артисты; ⚙ → настройки |
| ios-album | Страница альбома | `#album` / `IOSAlbumView` | Swift | треклист + play |
| ios-mini | Mini player + tab bar | `tabViewBottomAccessory` | Swift | кнопка списка воспроизведения на mini |
| ios-np | Сейчас играет | `#now-playing` / `IOSNowPlayingView` | Swift | барабан обложек −2…+2 + свайп ←/→; transport; vinyl-hint только в placeholder; открытие с mini |
| ios-recent | Недавнее | `#recent` / `IOSRecentView` | Swift | список альбомов |
| ios-fav | Избранное | `#favorites` / `IOSFavoritesView` | Swift | ♥ `#FF375F` |
| ios-dl | Скачанное | `#downloaded` / `IOSDownloadedView` | Swift | оффлайн-альбомы |
| ios-queue | Список воспроизведения | `#queue` / `IOSQueueView` | Swift | с mini или с NP |
| ios-settings | Настройки | `#settings` / `IOSSettingsView` | Swift | корень + drill-down |
| ios-settings-servers | Серверы | `#settings/servers` | Swift | список + деталь + проверка связи |
| ios-settings-playback | Воспроизведение | `#settings/playback` | Swift | gapless / кроссфейд (stub) / громкость |
| ios-settings-cache | Кеш и оффлайн | `#settings/cache` | Swift | FEAT5: кеш ≠ оффлайн |
| ios-settings-appearance | Внешний вид | `#settings/appearance` | Swift | Light / Dark / System |
| ios-launch | Лаунчер | `index.html` | обзор | ссылки light/dark + якоря |

### Навигация iOS
1. Библиотека → сегмент (треки / альбомы / артисты) → тап → страница альбома  
2. Play / тап трека → mini player + tab bar  
3. Тап mini player → Now Playing (sheet)  
4. Иконка списка на mini (или на NP) → Список воспроизведения (sheet)  
5. Tab bar: Библиотека · Недавнее · Избранное · Скачанное  
6. ⚙ в шапке Библиотеки → Настройки (Серверы / Воспроизведение / Кеш / Внешний вид)  
7. Свайп/chevron вниз закрывает sheet; ← закрывает настройки или секцию

## Порядок работы над новыми макетами
1. Прочитать `AGENTS.md` + `design-system/tokens.css`
2. Выбрать экран из таблицы; добавить строку при новом
3. Скопировать каркас из демо / iOS shell
4. Только `var(--*)`; light + dark при необходимости
5. Preview через `capture_preview.py`
