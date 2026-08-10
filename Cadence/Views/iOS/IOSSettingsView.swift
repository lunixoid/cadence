import SwiftUI

struct IOSSettingsView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            NavigationLink {
                IOSServersSettingsView()
            } label: {
                settingsLabel(.servers)
            }
            NavigationLink {
                IOSPlaybackSettingsView()
            } label: {
                settingsLabel(.playback)
            }
            NavigationLink {
                IOSCacheSettingsView()
            } label: {
                settingsLabel(.cache)
            }
            NavigationLink {
                IOSAppearanceSettingsView()
            } label: {
                settingsLabel(.appearance)
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Готово") {
                    uiState.closePreferences()
                    dismiss()
                }
            }
        }
    }

    private func settingsLabel(_ tab: PreferencesTab) -> some View {
        Label {
            Text(tab.label)
        } icon: {
            Image(systemName: tab.iconName)
                .foregroundStyle(CadenceTheme.accent(for: colorScheme))
        }
    }
}

struct IOSServersSettingsView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(JellyfinFavoritesSync.self) private var jellyfinFavoritesSync
    @Environment(\.colorScheme) private var colorScheme

    @State private var showAddServer = false
    @State private var pingMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(uiState.configuredServers) { server in
                    NavigationLink {
                        IOSServerDetailView(serverID: server.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(server.name)
                                    .font(.system(size: 16, weight: .semibold))
                                if server.isActive {
                                    Text("Активен")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(CadenceTheme.accent(for: colorScheme))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(CadenceTheme.accent(for: colorScheme).opacity(0.12), in: Capsule())
                                }
                            }
                            Text(server.url)
                                .font(.system(size: 12))
                                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                            Text("\(server.user) · \(server.authMethod)")
                                .font(.system(size: 12))
                                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let id = uiState.configuredServers[index].id
                        uiState.removeJellyfinServer(id)
                    }
                }
            }

            Section {
                Button("Добавить сервер") {
                    showAddServer = true
                }
            }

            if let pingMessage {
                Section {
                    Text(pingMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                }
            }
        }
        .navigationTitle("Серверы")
        .sheet(isPresented: $showAddServer) {
            NavigationStack {
                IOSAddServerView(isPresented: $showAddServer)
            }
        }
    }
}

struct IOSServerDetailView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(JellyfinFavoritesSync.self) private var jellyfinFavoritesSync
    @Environment(\.colorScheme) private var colorScheme

    let serverID: UUID

    @State private var statusMessage = ""

    private var server: JellyfinServer? {
        uiState.jellyfinServers.first { $0.id == serverID }
    }

    var body: some View {
        List {
            if let server {
                Section("Сервер") {
                    LabeledContent("Имя", value: server.name)
                    LabeledContent("URL", value: server.urlString)
                    LabeledContent("Пользователь", value: server.username.isEmpty ? server.userID : server.username)
                }

                Section {
                    Button("Сделать активным") {
                        uiState.connectJellyfinServer(server, favoritesSync: jellyfinFavoritesSync)
                        statusMessage = "Сервер активирован"
                    }
                    .disabled(server.isActive)

                    Button("Проверить связь") {
                        Task { await ping(server) }
                    }
                }

                if !statusMessage.isEmpty {
                    Section {
                        Text(statusMessage)
                            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                    }
                }
            } else {
                Text("Сервер не найден")
            }
        }
        .navigationTitle("Сервер")
    }

    private func ping(_ server: JellyfinServer) async {
        statusMessage = "Проверка…"
        do {
            let client = try JellyfinClient(server: server)
            _ = try await client.getAlbums(limit: 1)
            statusMessage = "Связь OK"
        } catch {
            statusMessage = "Ошибка: \(error.localizedDescription)"
        }
    }
}

struct IOSAddServerView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(JellyfinFavoritesSync.self) private var jellyfinFavoritesSync
    @Binding var isPresented: Bool

    @State private var authMethod: ConnectAuthMethod = .password
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var apiKey = ""
    @State private var errorMessage = ""
    @State private var isConnecting = false
    @State private var allowsUntrustedCertificate = true

    var body: some View {
        Form {
            Section {
                TextField("https://jellyfin.example.com", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                Toggle("Доверять сертификату сервера", isOn: $allowsUntrustedCertificate)
            } header: {
                Text("Адрес сервера")
            } footer: {
                Text("Включите, если сервер использует самоподписанный или корпоративный сертификат (иначе iOS блокирует TLS).")
            }

            Section {
                Picker("Метод", selection: $authMethod) {
                    ForEach(ConnectAuthMethod.allCases) { method in
                        Text(method.label).tag(method)
                    }
                }
                .pickerStyle(.segmented)

                if authMethod == .password {
                    TextField("Имя пользователя", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Пароль", text: $password)
                } else {
                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Новый сервер")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") { isPresented = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isConnecting ? "…" : "Подключить") {
                    connect()
                }
                .disabled(isConnecting || serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func connect() {
        errorMessage = ""
        isConnecting = true
        Task {
            do {
                let server: JellyfinServer
                if authMethod == .password {
                    server = try await JellyfinClient.authenticate(
                        serverURLString: serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
                        username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password,
                        allowsUntrustedCertificate: allowsUntrustedCertificate
                    )
                } else {
                    server = try await JellyfinClient.authenticateWithAPIKey(
                        serverURLString: serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
                        apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                        allowsUntrustedCertificate: allowsUntrustedCertificate
                    )
                }
                await MainActor.run {
                    uiState.connectJellyfinServer(server, favoritesSync: jellyfinFavoritesSync)
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    let ns = error as NSError
                    if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorSecureConnectionFailed, !allowsUntrustedCertificate {
                        errorMessage = "\(error.localizedDescription)\nВключите «Доверять сертификату сервера» и повторите."
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

struct IOSPlaybackSettingsView: View {
    @Environment(PlaybackController.self) private var playbackController

    @AppStorage("cadence.gaplessEnabled") private var gaplessEnabled = true
    @AppStorage("cadence.crossfadeEnabled") private var crossfadeEnabled = false
    @AppStorage("cadence.crossfadeLength") private var crossfadeLength = 3

    var body: some View {
        @Bindable var playback = playbackController
        Form {
            Section("Громкость") {
                Slider(value: $playback.volume, in: 0...100) {
                    Text("Громкость")
                } minimumValueLabel: {
                    Image(systemName: "speaker.fill")
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                }
                Text("\(Int(playback.volume))%")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Бесшовное воспроизведение", isOn: $gaplessEnabled)
                    .disabled(true)
                Toggle("Кроссфейд", isOn: $crossfadeEnabled)
                    .disabled(true)
                if crossfadeEnabled {
                    Stepper("Длина: \(crossfadeLength) с", value: $crossfadeLength, in: 1...12)
                        .disabled(true)
                }
            } footer: {
                Text("Gapless и кроссфейд появятся в FEAT3/FEAT4. Настройки сохраняются.")
            }
        }
        .navigationTitle("Воспроизведение")
    }
}

struct IOSCacheSettingsView: View {
    @Environment(OfflineStore.self) private var offlineStore
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("cadence.cacheLimitGB") private var cacheLimitGB = 10
    @State private var cacheRevision = 0

    var body: some View {
        let _ = cacheRevision
        let usedGb = Double(ArtworkCache.totalDiskUsageBytes() + AudioCache.totalDiskUsageBytes()) / 1_073_741_824
        let offlineGb = Double(offlineStore.totalBytes) / 1_073_741_824

        Form {
            Section("Кеш (авто)") {
                LabeledContent("Использовано", value: String(format: "%.1f ГБ из %d ГБ", usedGb, cacheLimitGB))
                Stepper("Лимит: \(cacheLimitGB) ГБ", value: $cacheLimitGB, in: 2...50)
                Button("Очистить кеш", role: .destructive) {
                    Task {
                        await ArtworkCache.shared.clearAll()
                        await AudioCache.shared.clearAll()
                        JellyfinLibraryCache.clearAll()
                        cacheRevision += 1
                    }
                }
            }

            Section {
                LabeledContent("Треков", value: "\(offlineStore.trackCount)")
                LabeledContent("Размер", value: String(format: "%.2f ГБ", offlineGb))
            } header: {
                Text("Оффлайн (явные загрузки)")
            } footer: {
                Text("Кеш — временные данные стриминга. Оффлайн — явно скачанные треки (FEAT5).")
            }
        }
        .navigationTitle("Кеш и оффлайн")
    }
}

struct IOSAppearanceSettingsView: View {
    @Environment(AppUIState.self) private var uiState

    var body: some View {
        @Bindable var ui = uiState
        Form {
            Picker("Тема", selection: $ui.appThemePreference) {
                ForEach(AppThemePreference.allCases) { preference in
                    Text(preference.label).tag(preference)
                }
            }
            .pickerStyle(.inline)
        }
        .navigationTitle("Внешний вид")
    }
}
