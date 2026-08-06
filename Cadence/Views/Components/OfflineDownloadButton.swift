import SwiftUI

struct OfflineDownloadButton: View {
    enum ProgressStyle {
        case accent
        case muted
    }

    @Environment(OfflineStore.self) private var offlineStore
    @Environment(AppUIState.self) private var uiState
    @Environment(\.colorScheme) private var colorScheme

    let track: Track?
    var size: CGFloat = 36
    var iconFont: CGFloat = 17
    var progressStyle: ProgressStyle = .accent

    @State private var isHovered = false

    private var isVisible: Bool {
        guard let track else { return false }
        return !track.fileURL.isFileURL && uiState.activeJellyfinClient != nil
    }

    private var state: OfflineState {
        guard let track else { return .none }
        return offlineStore.state(for: track.id)
    }

    var body: some View {
        Group {
            if isVisible {
                buttonContent
            }
        }
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible && isInteractive)
        .accessibilityHidden(!isVisible)
    }

    private var isInteractive: Bool {
        switch state {
        case .queued, .downloading:
            return false
        default:
            return true
        }
    }

    @ViewBuilder
    private var buttonContent: some View {
        switch state {
        case .queued:
            progressContent(progress: 0)
        case .downloading(let progress):
            progressContent(progress: progress)
        case .none, .ready, .failed:
            Image(systemName: iconName)
                .font(.system(size: iconFont))
                .foregroundStyle(iconColor)
                .scaleEffect(isHovered ? 1.08 : 1)
                .frame(width: size, height: size)
                .contentShape(Circle())
                .onTapGesture(perform: handleTap)
                .onHover { isHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
    }

    private func progressContent(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: 2)
            Circle()
                .trim(from: 0, to: min(max(progress, 0.02), 1))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "arrow.down")
                .font(.system(size: iconFont * 0.55, weight: .medium))
                .foregroundStyle(CadenceTheme.mutedText(for: colorScheme))
        }
        .frame(width: size * 0.55, height: size * 0.55)
        .frame(width: size, height: size)
        .contentShape(Circle())
    }

    private var iconName: String {
        switch state {
        case .none, .queued, .downloading:
            return "arrow.down.circle"
        case .ready:
            return "arrow.down.circle.fill"
        case .failed:
            return "arrow.clockwise"
        }
    }

    private var iconColor: Color {
        switch state {
        case .failed:
            return Color(red: 1, green: 0.231, blue: 0.188)
        case .ready:
            return isHovered
                ? CadenceTheme.primaryText(for: colorScheme)
                : CadenceTheme.iconColor(for: colorScheme)
        default:
            return isHovered
                ? CadenceTheme.primaryText(for: colorScheme)
                : CadenceTheme.iconColor(for: colorScheme)
        }
    }

    private var ringColor: Color {
        switch progressStyle {
        case .accent:
            return CadenceTheme.accent(for: colorScheme)
        case .muted:
            return CadenceTheme.mutedText(for: colorScheme)
        }
    }

    private var trackColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.10)
    }

    private func handleTap() {
        guard let track else { return }
        switch state {
        case .none, .failed:
            guard let client = uiState.activeJellyfinClient else { return }
            offlineStore.download(track: track, client: client, origin: .manual)
        case .ready:
            offlineStore.remove(trackID: track.id)
        case .queued, .downloading:
            break
        }
    }
}
