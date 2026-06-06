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

    private let outputDevices = ["Системное устройство"]

    var body: some View {
        if isOpen {
            VStack(spacing: 0) {
                prefsTitleBar
                tabToolbar
                tabContent
            }
            .frame(width: CadenceTheme.prefsWindowWidth, height: CadenceTheme.prefsWindowHeight)
            .background(CadenceTheme.prefsBackground)
            .clipShape(RoundedRectangle(cornerRadius: CadenceTheme.overlayWindowRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CadenceTheme.overlayWindowRadius, style: .continuous)
                    .stroke(CadenceTheme.prefsBorder, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.22), radius: 28, y: 12)
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

    private var prefsTitleBar: some View {
        HStack {
            OverlayTrafficLights(onClose: onClose)
            Text("Настройки")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CadenceTheme.prefsText)
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: 11 * 3 + 6 * 2)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(CadenceTheme.prefsToolbarBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CadenceTheme.prefsBorder).frame(height: 0.5)
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
                    }
                    .foregroundStyle(activeTab == tab ? CadenceTheme.prefsAccent : CadenceTheme.prefsSubtext)
                    .frame(minWidth: 80)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        if activeTab == tab {
                            Rectangle()
                                .fill(CadenceTheme.prefsAccent)
                                .frame(height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .background(CadenceTheme.prefsToolbarBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CadenceTheme.prefsBorder).frame(height: 0.5)
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
        .background(CadenceTheme.prefsContentBackground)
    }

    private var serversTab: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                if uiState.configuredServers.isEmpty {
                    VStack(spacing: 8) {
                        Text("Нет добавленных серверов")
                            .font(.system(size: 13))
                            .foregroundStyle(CadenceTheme.prefsSubtext)
                        Text("Нажмите +, чтобы подключить Jellyfin-сервер")
                            .font(.system(size: 12))
                            .foregroundStyle(CadenceTheme.prefsMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(CadenceTheme.prefsBorder, lineWidth: 0.5)
                    }
                } else {
                    serverTable
                }

                HStack(spacing: 0) {
                    Button(action: onAddServer) {
                        Text("+")
                            .frame(width: 28, height: 22)
                    }
                    .buttonStyle(.plain)

                    Button {
                        guard let selectedServerID else { return }
                        uiState.removeJellyfinServer(selectedServerID)
                        self.selectedServerID = uiState.configuredServers.first?.id
                    } label: {
                        Text("−")
                            .foregroundStyle(CadenceTheme.prefsMuted)
                            .frame(width: 28, height: 22)
                    }
                    .buttonStyle(.plain)
                    .disabled(uiState.configuredServers.isEmpty)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(CadenceTheme.prefsBorder, lineWidth: 0.5)
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
            HStack {
                Text("Название")
                Text("URL")
                Text("Статус")
            }
            .font(.system(size: 10, weight: .bold))
            .kerning(0.05 * 10)
            .textCase(.uppercase)
            .foregroundStyle(CadenceTheme.prefsMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .overlay(alignment: .bottom) {
                Rectangle().fill(CadenceTheme.prefsBorder).frame(height: 0.5)
            }

            ForEach(uiState.configuredServers) { server in
                Button {
                    selectedServerID = server.id
                } label: {
                    HStack {
                        HStack(spacing: 7) {
                            if server.isActive {
                                Circle()
                                    .fill(CadenceTheme.prefsAccent)
                                    .frame(width: 6, height: 6)
                            }
                            Text(server.name)
                                .font(.system(size: 13, weight: server.isActive ? .semibold : .regular))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(server.url)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(CadenceTheme.prefsSubtext)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(server.status.label)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(server.status == .online ? Color.green.opacity(0.12) : Color.black.opacity(0.06))
                            .foregroundStyle(server.status == .online ? Color(red: 0.1, green: 0.6, blue: 0.24) : CadenceTheme.prefsMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .frame(width: 70, alignment: .leading)
                    }
                    .foregroundStyle(CadenceTheme.prefsText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(selectedServerID == server.id ? CadenceTheme.prefsSelectionBackground : .clear)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(CadenceTheme.prefsBorder).frame(height: 0.5)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CadenceTheme.prefsBorder, lineWidth: 0.5)
        }
    }

    private func serverDetail(_ server: ServerEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(server.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(CadenceTheme.prefsText)

            detailField(title: "URL", value: server.url, monospaced: true)
            detailField(title: "Пользователь", value: server.user)
            detailField(title: "Авторизация", value: server.authMethod)

            Button("Проверить связь") {}
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(CadenceTheme.prefsAccent)
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
                .foregroundStyle(CadenceTheme.prefsMuted)
            Text(value)
                .font(.system(size: 12, design: monospaced ? .monospaced : .default))
                .foregroundStyle(CadenceTheme.prefsText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var playbackTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            prefsSectionLabel("Аудио-устройство")
            PrefsRow(label: "Вывод звука") {
                PrefsPicker(selection: $outputDevice, options: outputDevices)
            }
            PrefsRow(label: "Громкость по умолчанию") {
                PrefsSlider(value: $defaultVolume, range: 0...100, unit: "%")
            }

            prefsDivider
            prefsSectionLabel("Воспроизведение")
            PrefsRow(label: "Бесшовное воспроизведение") {
                PrefsToggle(isOn: $gaplessEnabled)
            }
            PrefsRow(label: "Кроссфейд") {
                PrefsToggle(isOn: $crossfadeEnabled)
            }
            if crossfadeEnabled {
                PrefsRow(label: "Длина кроссфейда") {
                    PrefsSlider(value: $crossfadeLength, range: 1...12, unit: " с")
                }
            }
        }
    }

    private var cacheTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.08))
                        Capsule()
                            .fill(CadenceTheme.prefsAccent)
                            .frame(width: geometry.size.width * 0)
                    }
                }
                .frame(width: 220, height: 6)

                Text("0 ГБ занято из \(cacheLimitGB) ГБ")
                    .font(.system(size: 11))
                    .foregroundStyle(CadenceTheme.prefsMuted)
            }
            .padding(.leading, 172)

            Button("Очистить кеш") {}
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CadenceTheme.prefsText)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(CadenceTheme.prefsBorder, lineWidth: 0.5)
                }
                .buttonStyle(.plain)
                .padding(.leading, 172)

            prefsDivider
            prefsSectionLabel("Скачанное")

            Text("Нет скачанного контента")
                .font(.system(size: 13))
                .foregroundStyle(CadenceTheme.prefsSubtext)
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(CadenceTheme.prefsBorder, lineWidth: 0.5)
                }
        }
    }

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            prefsSectionLabel("Тема оформления")
            PrefsRow(label: "Тема") {
                HStack(spacing: 2) {
                    ForEach(AppThemePreference.allCases) { theme in
                        Button {
                            uiState.appThemePreference = theme
                        } label: {
                            Text(theme.label)
                                .font(.system(size: 13, weight: uiState.appThemePreference == theme ? .semibold : .regular))
                                .foregroundStyle(uiState.appThemePreference == theme ? CadenceTheme.prefsText : CadenceTheme.prefsSubtext)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                                .background(uiState.appThemePreference == theme ? Color.white : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .shadow(color: uiState.appThemePreference == theme ? .black.opacity(0.1) : .clear, radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.black.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func prefsSectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .kerning(0.05 * 11)
            .foregroundStyle(CadenceTheme.prefsMuted)
            .padding(.top, 4)
    }

    private var prefsDivider: some View {
        Rectangle()
            .fill(CadenceTheme.prefsBorder)
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}

private struct PrefsRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(CadenceTheme.prefsText)
                .frame(width: 160, alignment: .trailing)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 32)
    }
}

private struct PrefsToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? CadenceTheme.prefsAccent : Color.black.opacity(0.16))
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
                        .fill(Color.black.opacity(0.1))
                        .frame(height: isHovered ? 5 : 3)
                    Capsule()
                        .fill(CadenceTheme.prefsAccent)
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
            .frame(width: 180, height: 20)
            .animation(.easeOut(duration: 0.12), value: isHovered)

            Text("\(value)\(unit)")
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(CadenceTheme.prefsSubtext)
                .frame(minWidth: 40, alignment: .leading)
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
        .frame(width: 220)
    }
}
