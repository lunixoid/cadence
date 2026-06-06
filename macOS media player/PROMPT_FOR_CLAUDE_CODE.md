# Промпт для Claude Code: реализация Cadence

## Контекст

Cadence — нативный macOS аудио-плеер (Swift + SwiftUI) с интеграцией Jellyfin и поддержкой локальных файлов. Полная спецификация — в `SPEC.md`. Pixel-perfect макеты всех экранов — в `/ux/` (JSX-компоненты с точными размерами, цветами, отступами). Реализации кода пока нет — нужно создать проект с нуля.

## Задача

Создай macOS-приложение Cadence (Xcode project, Swift, SwiftUI, target macOS 14.0+). Реализуй Фазу 1 (MVP) из SPEC.md. Макеты в `/ux/` — это source of truth для UI: бери размеры, цвета, отступы, структуру компонентов оттуда.

## Что реализовать (Фаза 1)

### 1. Скелет приложения

Создай Xcode проект `Cadence` (macOS App, SwiftUI lifecycle). Структура:

```
Cadence/
├── CadenceApp.swift              # @main, WindowGroup
├── Models/
│   ├── Track.swift                # id, title, artist, album, duration, artworkURL, etc.
│   ├── Album.swift
│   ├── Artist.swift
│   ├── Playlist.swift
│   └── JellyfinServer.swift       # url, username, token, authMethod
├── Services/
│   ├── AudioEngine.swift          # AVAudioEngine wrapper
│   ├── JellyfinClient.swift       # REST API client
│   ├── PlaybackQueue.swift        # queue, shuffle, repeat logic
│   ├── CacheManager.swift         # audio + artwork caching
│   └── KeychainHelper.swift       # token storage
├── ViewModels/
│   ├── PlayerViewModel.swift      # @Observable, main playback state
│   ├── LibraryViewModel.swift     # albums, artists, tracks from Jellyfin
│   ├── QueueViewModel.swift
│   └── EQViewModel.swift
├── Views/
│   ├── MainWindow.swift           # NavigationSplitView layout
│   ├── Sidebar/
│   │   └── SidebarView.swift
│   ├── Content/
│   │   ├── AlbumGridView.swift
│   │   ├── AlbumDetailView.swift
│   │   ├── TrackListView.swift
│   │   └── ArtistView.swift
│   ├── Player/
│   │   └── NowPlayingBar.swift
│   ├── Queue/
│   │   └── QueuePanel.swift
│   ├── Equalizer/
│   │   └── EQWindow.swift
│   ├── Settings/
│   │   ├── PreferencesWindow.swift
│   │   ├── ServerSettingsTab.swift
│   │   ├── PlaybackSettingsTab.swift
│   │   ├── CacheSettingsTab.swift
│   │   └── AppearanceSettingsTab.swift
│   └── Connect/
│       └── ConnectServerView.swift
└── Resources/
    └── Assets.xcassets            # AppIcon
```

### 2. Аудио-движок (AudioEngine.swift)

На базе `AVAudioEngine`:

```
AVAudioPlayerNode → AVAudioUnitEQ (10 bands) → mainMixerNode → output
```

Функциональность:
- play(url: URL) — загрузка и воспроизведение (локальные файлы и HTTP URLs из Jellyfin)
- pause(), resume(), stop()
- seek(to: TimeInterval)
- volume: Float (0..1, независимый от системного)
- currentTime / duration — publishers для UI binding
- EQ: 10 полос, gain -12..+12 dB, bypass toggle
- Делегат/callback при окончании трека → переход к следующему

### 3. Jellyfin Client (JellyfinClient.swift)

REST API клиент поверх URLSession + async/await:

- authenticate(server: URL, username: String, password: String) → token
- authenticate(server: URL, apiKey: String) → token
- getAlbums(limit:, offset:) → [Album]
- getAlbumTracks(albumId:) → [Track]
- getArtists() → [Artist]
- getPlaylists() → [Playlist]
- getStreamURL(itemId:) → URL
- getArtworkURL(itemId:, maxWidth:) → URL
- search(query:) → SearchResults
- reportPlaybackStart/Progress/Stop — scrobbling
- Сохранение токена в Keychain
- Поддержка нескольких серверов (переключение)

Headers: `X-Emby-Authorization` с DeviceId, Client, Version, Token.

### 4. UI — точно по макетам из /ux/

Изучи каждый JSX-файл в `/ux/` и реализуй SwiftUI-эквивалент с теми же размерами, цветами и поведением:

- `cadence-sidebar.jsx` → SidebarView.swift (220px, секции, иконки, hover/selected states)
- `cadence-content.jsx` → AlbumGridView.swift (grid 160px карточки, toolbar 52px)
- `cadence-album-page.jsx` → AlbumDetailView.swift (hero 180px обложка, треклист, context menu)
- `cadence-player.jsx` → NowPlayingBar.swift (96px, три зоны, seekable progress, volume)
- `cadence-queue.jsx` → QueuePanel.swift (300px slide-in, три секции, drag-and-drop reorder)
- `cadence-eq.jsx` → EQWindow.swift (480px floating panel, 10 слайдеров, пресеты)
- `cadence-prefs.jsx` → PreferencesWindow.swift (560px, 4 таба)
- `cadence-connect.jsx` → ConnectServerView.swift (420px modal, 2 шага)
- `cadence-icons.jsx` → набор SF Symbol-style SVG иконок (можно использовать system SF Symbols где совпадают, кастомные — через Shape/Path)

Цвета — из SPEC.md секция 8.9. Обе темы (light/dark) через `@Environment(\.colorScheme)`.

### 5. Playback Queue

- Очередь воспроизведения с поддержкой shuffle (Fisher-Yates) и repeat (off / all / one)
- «Играть далее» / «Добавить в очередь»
- Drag-and-drop reorder в секции «Далее»
- Автовоспроизведение остатка альбома/плейлиста

### 6. Media Keys и Now Playing

- `MPRemoteCommandCenter`: play, pause, nextTrack, previousTrack, changePlaybackPosition
- `MPNowPlayingInfoCenter`: title, artist, album, artwork, duration, elapsed time
- Обновление при смене трека

### 7. Базовый эквалайзер

- 10 полос через AVAudioUnitEQ
- Встроенные пресеты (Flat, Rock, Pop, Jazz, Classical, Electronic, Hip-Hop, Acoustic, Bass Boost, Vocal Boost)
- Пользовательские пресеты (сохранение в UserDefaults)
- Bypass toggle

### 8. Сохранение состояния

При закрытии приложения сохранять (SwiftData или Codable + UserDefaults):
- Текущий трек, позиция, очередь
- Shuffle / repeat режимы
- EQ настройки
- Громкость
- Размер/позиция окна
- Активный сервер

## Требования к коду

- Swift 5.9+, macOS 14.0+
- SwiftUI lifecycle (@main, WindowGroup, Settings scene)
- @Observable macro для ViewModels (не ObservableObject)
- async/await для сетевых запросов
- Structured concurrency (TaskGroup для параллельных загрузок)
- Минимум зависимостей — всё нативно
- Разделение ответственности: UI ничего не знает о Jellyfin API; AudioEngine ничего не знает об источнике треков
- Обработка ошибок: все сетевые и файловые операции с do/catch, user-facing alerts

## Важно

- Макеты в `/ux/` — единственный источник правды для визуала. Не придумывай свой дизайн
- Перед реализацией каждого view — прочитай соответствующий JSX-файл и извлеки точные значения
- Если SF Symbol совпадает с иконкой из макета — используй SF Symbol. Если нет — рисуй Shape/Path
- Preferences window — отдельная macOS Settings scene
- EQ window — floating panel (NSPanel / .windowStyle(.plain) + .windowLevel(.floating))
- Sidebar должна использовать стандартный macOS sidebar material (`.background(.ultraThinMaterial)`)
