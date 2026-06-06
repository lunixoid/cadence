import SwiftUI

enum ConnectStep {
    case form
    case checking
    case success
}

enum ConnectAuthMethod: String, CaseIterable, Identifiable {
    case password
    case apiKey

    var id: String { rawValue }

    var label: String {
        switch self {
        case .password: return "Логин / Пароль"
        case .apiKey: return "API Key"
        }
    }
}

struct ConnectWindowView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(JellyfinFavoritesSync.self) private var jellyfinFavoritesSync
    @Environment(\.colorScheme) private var colorScheme

    let isOpen: Bool
    let onClose: () -> Void

    @State private var step: ConnectStep = .form
    @State private var authMethod: ConnectAuthMethod = .password
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var apiKey = ""
    @State private var errorMessage = ""
    @State private var connectedServer: JellyfinServer?

    var body: some View {
        if isOpen {
            VStack(spacing: 0) {
                OverlayTitleBar(title: step == .success ? "Сервер добавлен" : "Новый сервер", onClose: close)

                Group {
                    switch step {
                    case .form, .checking:
                        formContent
                    case .success:
                        successContent
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
            .frame(width: CadenceTheme.connectWindowWidth)
            .background {
                VisualEffectBackground(material: .hudWindow)
                    .overlay {
                        colorScheme == .dark
                            ? Color(red: 0.133, green: 0.133, blue: 0.149).opacity(0.97)
                            : Color(red: 0.98, green: 0.98, blue: 0.98)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(CadenceTheme.borderColor(for: colorScheme), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.16), radius: 28, y: 12)
            .overlayAppear(isPresented: isOpen)
        }
    }

    private var formContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                CadenceAppIconView(size: 64)
                VStack(spacing: 4) {
                    Text("Подключение к Jellyfin")
                        .font(.system(size: 18, weight: .bold))
                        .kerning(-0.02 * 18)
                        .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                    Text("Введите адрес вашего сервера")
                        .font(.system(size: 13))
                        .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                }
            }

            VStack(spacing: 12) {
                ConnectField(
                    label: "Адрес сервера",
                    text: $serverURL,
                    placeholder: "https://jellyfin.example.com",
                    hasError: !errorMessage.isEmpty
                )

                if !errorMessage.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                authSegmentedControl

                if authMethod == .password {
                    ConnectField(label: "Имя пользователя", text: $username, placeholder: "admin")
                    ConnectField(label: "Пароль", text: $password, placeholder: "••••••••", isSecure: true)
                } else {
                    ConnectField(label: "API Key", text: $apiKey, placeholder: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
                }
            }

            HStack(spacing: 10) {
                Button("Отмена", action: close)
                    .buttonStyle(ConnectSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)

                Button(action: connect) {
                    HStack(spacing: 8) {
                        if step == .checking {
                            ConnectSpinner()
                        }
                        Text(step == .checking ? "Подключение..." : "Подключиться")
                    }
                }
                .buttonStyle(ConnectPrimaryButtonStyle())
                .disabled(step == .checking || serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var successContent: some View {
        VStack(spacing: 22) {
            ConnectSuccessMark()
            VStack(spacing: 4) {
                Text("Подключено!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                Text(connectedServer?.name ?? serverURL)
                    .font(.system(size: 13))
                    .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
            }

            VStack(spacing: 8) {
                infoRow(label: "Пользователь", value: displayUsername)
                infoRow(label: "Треков в библиотеке", value: "—")
                infoRow(label: "Статус", value: "Онлайн", valueColor: Color(red: 0.2, green: 0.78, blue: 0.35))
            }
            .padding(16)
            .background(CadenceTheme.secondaryButtonBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(CadenceTheme.borderColor(for: colorScheme), lineWidth: 0.5)
            }

            Button("Начать", action: finish)
                .buttonStyle(ConnectPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }

    private var authSegmentedControl: some View {
        HStack(spacing: 2) {
            ForEach(ConnectAuthMethod.allCases) { method in
                Button {
                    authMethod = method
                } label: {
                    Text(method.label)
                        .font(.system(size: 13, weight: authMethod == method ? .semibold : .regular))
                        .foregroundStyle(authMethod == method ? CadenceTheme.primaryText(for: colorScheme) : CadenceTheme.secondaryText(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(authMethod == method ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.white) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: authMethod == method && colorScheme == .light ? .black.opacity(0.1) : .clear, radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(CadenceTheme.trackBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var displayUsername: String {
        if authMethod == .apiKey {
            return "API Key"
        }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func infoRow(label: String, value: String, valueColor: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(valueColor ?? CadenceTheme.primaryText(for: colorScheme))
        }
    }

    private func connect() {
        errorMessage = ""
        step = .checking

        Task {
            do {
                let server: JellyfinServer
                if authMethod == .password {
                    server = try await JellyfinClient.authenticate(
                        serverURLString: serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
                        username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password
                    )
                } else {
                    server = try await JellyfinClient.authenticateWithAPIKey(
                        serverURLString: serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
                        apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                await MainActor.run {
                    connectedServer = server
                    step = .success
                }
            } catch {
                await MainActor.run {
                    step = .form
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func finish() {
        guard let server = connectedServer else { return }
        uiState.connectJellyfinServer(server, favoritesSync: jellyfinFavoritesSync)
        resetForm()
        onClose()
    }

    private func close() {
        resetForm()
        onClose()
    }

    private func resetForm() {
        step = .form
        errorMessage = ""
        serverURL = ""
        username = ""
        password = ""
        apiKey = ""
        connectedServer = nil
    }
}

private struct ConnectField: View {
    @Environment(\.colorScheme) private var colorScheme

    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure = false
    var hasError = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(colorScheme == .dark ? Color.white.opacity(0.07) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .focused($isFocused)
        }
    }

    private var borderColor: Color {
        if hasError { return .red }
        if isFocused { return CadenceTheme.accent(for: colorScheme) }
        return CadenceTheme.borderColor(for: colorScheme)
    }
}

private struct CadenceAppIconView: View {
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.215, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.42, green: 0.31, blue: 0.73),
                        Color(red: 0.23, green: 0.49, blue: 0.91),
                        Color(red: 0.16, green: 0.75, blue: 0.81),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                EqualizerBarsView(color: .white.opacity(0.85), size: size * 0.4)
            }
            .shadow(color: Color(red: 0.23, green: 0.49, blue: 0.91).opacity(0.35), radius: 10, y: 4)
    }
}

private struct ConnectSpinner: View {
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.15, to: 0.85)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 0.72).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

private struct ConnectSuccessMark: View {
    @State private var scale: CGFloat = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.12))
                .frame(width: 72, height: 72)
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 58, height: 58)
            Circle()
                .fill(Color(red: 0.2, green: 0.78, blue: 0.35))
                .frame(width: 44, height: 44)
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                scale = 1
            }
        }
    }
}

private struct ConnectPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(height: 34)
            .background(CadenceTheme.accent(for: colorScheme).opacity(isEnabled ? 1 : 0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private struct ConnectSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
            .frame(height: 34)
            .background(CadenceTheme.secondaryButtonBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(CadenceTheme.borderColor(for: colorScheme), lineWidth: 0.5)
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
