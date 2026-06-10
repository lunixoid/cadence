import SwiftUI

enum PreferencesTab: String, CaseIterable, Identifiable {
    case servers
    case playback
    case cache
    case appearance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .servers: return "Серверы"
        case .playback: return "Воспроизведение"
        case .cache: return "Кеш"
        case .appearance: return "Внешний вид"
        }
    }

    var iconName: String {
        switch self {
        case .servers: return "server.rack"
        case .playback: return "play.circle"
        case .cache: return "externaldrive"
        case .appearance: return "circle.lefthalf.filled"
        }
    }
}

struct ServerEntry: Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: String
    var status: ServerStatus
    var isActive: Bool
    var user: String
    var authMethod: String

    enum ServerStatus {
        case online
        case offline

        var label: String {
            switch self {
            case .online: return "Онлайн"
            case .offline: return "Офлайн"
            }
        }
    }
}

struct PreferencesWindowView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(\.colorScheme) private var colorScheme

    let isOpen: Bool
    let onClose: () -> Void
    let onAddServer: () -> Void

    @State private var activeTab: PreferencesTab = .servers
    @State private var selectedServerID: UUID?
    @State private var outputDevice = "Системное устройство"
    @State private var defaultVolume = 80
    @State private var gaplessEnabled = true
    @State private var crossfadeEnabled = false
    @State private var crossfadeLength = 3
    @State private var cacheLimitGB = 10
    @State private var cacheRevision = 0

    private let outputDevices = ["Системное устройство"]

    private var cs: ColorScheme { colorScheme }

    var body: some View {
        if isOpen {
            VStack(spacing: 0) {
                prefsTitleBar
                tabToolbar
                tabContent
            }
            .frame(width: CadenceTheme.prefsWindowWidth, height: CadenceTheme.prefsWindowHeight)
            .background(CadenceTheme.prefsBackground(for: cs))
            .clipShape(RoundedRectangle(cornerRadius: CadenceTheme.overlayWindowRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CadenceTheme.overlayWindowRadius, style: .continuous)
                    .stroke(CadenceTheme.prefsBorder(for: cs), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(cs == .dark ? 0.5 : 0.22), radius: 28, y: 12)
            .overlayAppear(isPresented: isOpen)
            .onAppear {
                selectedServerID = uiState.configuredServers.first?.id
            }
            .onChange(of: uiState.configuredServers.count) { _, _ in
                if selectedServerID == nil {
                    selectedServerID = uiState.configuredServers.first?.id
                }
            }
        }
    }

    // MARK: - Chrome

    private var prefsTitleBar: some View {
        HStack {
            PrefsCloseButton(onClose: onClose)
            Text("Настройки")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CadenceTheme.prefsText(for: cs))
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: 12)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(CadenceTheme.prefsToolbarBackground(for: cs))
        .overlay(alignment: .bottom) {
            Rectangle().fill(CadenceTheme.prefsBorder(for: cs)).frame(height: 0.5)
        }
    }

    private var tabToolbar: some View {
        HStack(spacing: 0) {
            ForEach(PreferencesTab.allCases) { tab in
                Button {
                    activeTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 18))
                        Text(tab.label)
                            .font(.system(size: 11, weight: activeTab == tab ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(activeTab == tab ? CadenceTheme.prefsAccent(for: cs) : CadenceTheme.prefsSubtext(for: cs))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(activeTab == tab ? CadenceTheme.prefsAccent(for: cs) : Color.clear)
                            .frame(height: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(CadenceTheme.prefsToolbarBackground(for: cs))
        .overlay(alignment: .bottom) {
            Rectangle().fill(CadenceTheme.prefsBorder(for: cs)).frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch activeTab {
            case .servers:
                serversTab
            case .playback:
                playbackTab
            case .cache:
                cacheTab
            case .appearance:
                appearanceTab
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CadenceTheme.prefsBackground(for: cs))
    }

    // MARK: - Servers tab

    private var serversTab: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                if uiState.configuredServers.isEmpty {
                    VStack(spacing: 8) {
                        Text("Нет добавленных серверов")
                            .font(.system(size: 13))
                            .foregroundStyle(CadenceTheme.prefsSubtext(for: cs))
                        Text("Нажмите +, чтобы подключить Jellyfin-сервер")
                            .font(.system(size: 12))
                            .foregroundStyle(CadenceTheme.prefsMuted(for: cs))
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .background(CadenceTheme.prefsCardBackground(for: cs))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(CadenceTheme.prefsBorder(for: cs), lineWidth: 0.5)
                    }
                } else {
                    serverTable
                }

                HStack(spacing: 0) {
                    Button(action: onAddServer) {
                        Text("+")
                            .foregroundStyle(CadenceTheme.prefsText(for: cs))
                            .frame(width: 28, height: 22)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(CadenceTheme.prefsBorder(for: cs))
                        .frame(width: 0.5, height: 22)

                    Button {
                        guard let selectedServerID else { return }
                        uiState.removeJellyfinServer(selectedServerID)
                        self.selectedServerID = uiState.configuredServers.first?.id
                    } label: {
                        Text("−")
                            .foregroundStyle(CadenceTheme.prefsMuted(for: cs))
                            .frame(width: 28, height: 22)
                    }
                    .buttonStyle(.plain)
                    .disabled(uiState.configuredServers.isEmpty)
                }
                .background(CadenceTheme.prefsCardBackground(for: cs))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(CadenceTheme.prefsBorder(for: cs), lineWidth: 0.5)
                }
            }
            .frame(maxWidth: .infinity)

            if let selected = uiState.configuredServers.first(where: { $0.id == selectedServerID }) {
                serverDetail(selected)
            }
        }
    }

    private var serverTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Название")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("URL")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Статус")
                    .frame(width: 70, alignment: .leading)
            }
            .font(.system(size: 10, weight: .bold))
            .kerning(0.05 * 10)
            .textCase(.uppercase)
            .foregroundStyle(CadenceTheme.prefsMuted(for: cs))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .overlay(alignment: .bottom) {
                Rectangle().fill(CadenceTheme.prefsBorder(for: cs)).frame(height: 0.5)
            }

            ForEach(uiState.configuredServers) { server in
                Button {
                    selectedServerID = server.id
                } label: {
                    HStack(spacing: 0) {
                        HStack(spacing: 7) {
                            if server.isActive {
                                Circle()
                                    .fill(CadenceTheme.prefsAccent(for: cs))
                                    .frame(width: 6, height: 6)
                            }
                            Text(server.name)
                                .font(.system(size: 13, weight: server.isActive ? .semibold : .regular))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(server.url)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(CadenceTheme.prefsSubtext(for: cs))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 8)

                        serverStatusBadge(server.status)
                            .frame(width: 70, alignment: .leading)
                    }
                    .foregroundStyle(CadenceTheme.prefsText(for: cs))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(selectedServerID == server.id ? CadenceTheme.prefsSelectionBackground(for: cs) : .clear)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(CadenceTheme.prefsBorder(for: cs)).frame(height: 0.5)
                }
            }
        }
        .background(CadenceTheme.prefsCardBackground(for: cs))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CadenceTheme.prefsBorder(for: cs), lineWidth: 0.5)
        }
    }

    private func serverStatusBadge(_ status: ServerEntry.ServerStatus) -> some View {
        Text(status.label)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(status == .online
                ? Color.green.opacity(cs == .dark ? 0.18 : 0.12)
                : (cs == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
            )
            .foregroundStyle(status == .online ? Color(red: 0.1, green: 0.6, blue: 0.24) : CadenceTheme.prefsMuted(for: cs))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func serverDetail(_ server: ServerEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(server.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(CadenceTheme.prefsText(for: cs))

            detailField(title: "URL", value: server.url, monospaced: true)
            detailField(title: "Пользователь", value: server.user)
            detailField(title: "Авторизация", value: server.authMethod)

            Button("Проверить связь") {}
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(CadenceTheme.prefsAccent(for: cs))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .buttonStyle(.plain)
        }
        .frame(width: 190, alignment: .leading)
    }

    private func detailField(title: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(0.05 * 10)
                .foregroundStyle(CadenceTheme.prefsMuted(for: cs))
            Text(value)
                .font(.system(size: 12, design: monospaced ? .monospaced : .default))
                .foregroundStyle(CadenceTheme.prefsText(for: cs))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Playback tab

    private var playbackTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            prefsSectionLabel("Аудио-устройство", first: true)
            PrefsCard {
                PrefsCardRow(label: "Вывод звука") {
                    PrefsPicker(selection: $outputDevice, options: outputDevices)
                }
                PrefsCardRow(label: "Громкость по умолчанию", isLast: true) {
                    PrefsSlider(value: $defaultVolume, range: 0...100, unit: "%")
                }
            }

            prefsSectionLabel("Воспроизведение")
            PrefsCard {
                PrefsCardRow(label: "Бесшовное воспроизведение") {
                    PrefsToggle(isOn: $gaplessEnabled)
                }
                PrefsCardRow(label: "Кроссфейд", isLast: !crossfadeEnabled) {
                    PrefsToggle(isOn: $crossfadeEnabled)
                }
                if crossfadeEnabled {
                    PrefsCardRow(label: "Длина кроссфейда", isLast: true) {
                        PrefsSlider(value: $crossfadeLength, range: 1...12, unit: " с")
                    }
                }
            }
        }
    }

    // MARK: - Cache tab

    private var cacheTab: some View {
        let _ = cacheRevision
        let usedGb = Double(ArtworkCache.totalDiskUsageBytes()) / 1_073_741_824
        let pct = min(usedGb / Double(cacheLimitGB), 1.0)

        return VStack(alignment: .leading, spacing: 0) {
            prefsSectionLabel("Хранилище", first: true)
            PrefsCard {
                VStack(spacing: 7) {
                    HStack {
                        Text("Использовано")
                            .font(.system(size: 13))
                            .foregroundStyle(CadenceTheme.prefsText(for: cs))
                        Spacer()
                        Text(String(format: "%.1f ГБ из %d ГБ", usedGb, cacheLimitGB))
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(CadenceTheme.prefsMuted(for: cs))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(CadenceTheme.prefsSliderTrack(for: cs))
                            Capsule()
                                .fill(pct > 0.8 ? Color.orange : CadenceTheme.prefsAccent(for: cs))
                                .frame(width: geo.size.width * pct)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(CadenceTheme.prefsBorder(for: cs)).frame(height: 0.5)
                }

                PrefsCardRow(label: "Максимальный размер", isLast: true) {
                    PrefsSlider(value: $cacheLimitGB, range: 2...50, unit: " ГБ")
                }
            }

            HStack {
                Spacer()
                Button("Очистить кеш") {
                    Task {
                        await ArtworkCache.shared.clearAll()
                        await AudioCache.shared.clearAll()
                        JellyfinLibraryCache.clearAll()
                        cacheRevision += 1
                    }
                }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CadenceTheme.prefsText(for: cs))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(CadenceTheme.prefsCardBackground(for: cs))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(CadenceTheme.prefsBorder(for: cs), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                    .buttonStyle(.plain)
            }
            .padding(.top, 10)

            prefsSectionLabel("Скачанное")
            PrefsCard {
                Text("Нет скачанного контента")
                    .font(.system(size: 13))
                    .foregroundStyle(CadenceTheme.prefsSubtext(for: cs))
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
    }

    // MARK: - Appearance tab

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            prefsSectionLabel("Тема оформления", first: true)
            PrefsCard {
                PrefsCardRow(label: "Оформление", isLast: true) {
                    HStack(spacing: 2) {
                        ForEach(AppThemePreference.allCases) { theme in
                            Button {
                                uiState.appThemePreference = theme
                            } label: {
                                Text(theme.label)
                                    .font(.system(size: 13, weight: uiState.appThemePreference == theme ? .semibold : .regular))
                                    .foregroundStyle(
                                        uiState.appThemePreference == theme
                                            ? CadenceTheme.prefsText(for: cs)
                                            : CadenceTheme.prefsSubtext(for: cs)
                                    )
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 4)
                                    .background(
                                        uiState.appThemePreference == theme
                                            ? CadenceTheme.prefsSegmentButtonSelected(for: cs)
                                            : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    .shadow(
                                        color: uiState.appThemePreference == theme
                                            ? .black.opacity(cs == .dark ? 0.3 : 0.1)
                                            : .clear,
                                        radius: 2, y: 1
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(CadenceTheme.prefsSegmentBackground(for: cs))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    // MARK: - Helpers

    private func prefsSectionLabel(_ title: String, first: Bool = false) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .kerning(0.06 * 11)
            .foregroundStyle(CadenceTheme.prefsMuted(for: cs))
            .padding(.top, first ? 0 : 20)
            .padding(.bottom, 5)
            .padding(.leading, 3)
    }
}

// MARK: - Close button

private struct PrefsCloseButton: View {
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onClose) {
            ZStack {
                Circle()
                    .fill(Color(red: 1, green: 0.373, blue: 0.341))
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.5)
                    }

                if isHovered {
                    Path { p in
                        p.move(to: CGPoint(x: 3, y: 3))
                        p.addLine(to: CGPoint(x: 9, y: 9))
                        p.move(to: CGPoint(x: 9, y: 3))
                        p.addLine(to: CGPoint(x: 3, y: 9))
                    }
                    .stroke(Color.black.opacity(0.55), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                    .frame(width: 12, height: 12)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Card container

private struct PrefsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(CadenceTheme.prefsCardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(CadenceTheme.prefsBorder(for: colorScheme), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 3, y: 1)
    }
}

// MARK: - Card row

private struct PrefsCardRow<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    var sublabel: String? = nil
    var isLast: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(CadenceTheme.prefsText(for: colorScheme))
                    .lineLimit(1)
                if let sublabel {
                    Text(sublabel)
                        .font(.system(size: 11))
                        .foregroundStyle(CadenceTheme.prefsSubtext(for: colorScheme))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content()
                .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, sublabel != nil ? 8 : 9)
        .frame(minHeight: 38)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(CadenceTheme.prefsBorder(for: colorScheme)).frame(height: 0.5)
            }
        }
    }
}

// MARK: - Controls

private struct PrefsToggle: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? CadenceTheme.prefsAccent(for: colorScheme) : CadenceTheme.prefsToggleTrack(for: colorScheme))
                    .frame(width: 36, height: 20)
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                    .padding(2)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isOn)
    }
}

private struct PrefsSlider: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            GeometryReader { geometry in
                let ratio = CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CadenceTheme.prefsSliderTrack(for: colorScheme))
                        .frame(height: isHovered ? 5 : 3)
                    Capsule()
                        .fill(CadenceTheme.prefsAccent(for: colorScheme))
                        .frame(width: geometry.size.width * ratio, height: isHovered ? 5 : 3)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let newRatio = min(max(gesture.location.x / geometry.size.width, 0), 1)
                            value = range.lowerBound + Int((newRatio * CGFloat(range.upperBound - range.lowerBound)).rounded())
                        }
                )
                .onHover { isHovered = $0 }
            }
            .frame(width: 150, height: 20)
            .animation(.easeOut(duration: 0.12), value: isHovered)

            Text("\(value)\(unit)")
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(CadenceTheme.prefsSubtext(for: colorScheme))
                .frame(minWidth: 36, alignment: .trailing)
        }
    }
}

private struct PrefsPicker: View {
    @Binding var selection: String
    let options: [String]

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(option).tag(option)
            }
        }
        .labelsHidden()
        .frame(width: 200)
    }
}
