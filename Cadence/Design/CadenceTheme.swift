import SwiftUI

enum CadenceTheme {
    // MARK: - Layout

    static let sidebarWidth: CGFloat = 220
    static let trafficLightsAreaHeight: CGFloat = 52
    static let toolbarHeight: CGFloat = 52
    static let nowPlayingBarHeight: CGFloat = 72
    static let defaultWindowWidth: CGFloat = 1100
    static let defaultWindowHeight: CGFloat = 700

    static let sidebarItemHeight: CGFloat = 28
    static let sidebarItemRadius: CGFloat = 6
    static let sidebarItemHorizontalPadding: CGFloat = 10
    static let sidebarItemMargin: CGFloat = 8

    static let albumCardWidth: CGFloat = 160
    static let albumCoverSize: CGFloat = 148
    static let albumCoverRadius: CGFloat = 8
    static let albumCardRadius: CGFloat = 10

    static let albumHeroCoverSize: CGFloat = 180
    static let albumHeroCoverRadius: CGFloat = 10

    static let trackRowHeight: CGFloat = 38
    static let navButtonSize: CGFloat = 28
    static let navButtonRadius: CGFloat = 6

    static let progressBarHeight: CGFloat = 4
    static let progressBarHoverHeight: CGFloat = 6
    static let progressBarRadius: CGFloat = 3
    static let progressThumbSize: CGFloat = 10

    static let volumeSliderWidth: CGFloat = 80
    static let volumeSliderHeight: CGFloat = 4

    static let miniCoverSize: CGFloat = 48
    static let miniCoverRadius: CGFloat = 6
    static let playButtonSize: CGFloat = 34
    static let playOverlaySize: CGFloat = 32

    // MARK: - Colors

    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.04, green: 0.52, blue: 1.0) : Color(red: 0, green: 0.478, blue: 1.0)
    }

    static func windowBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.157, green: 0.157, blue: 0.157) : .white
    }

    static func contentBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.118, green: 0.118, blue: 0.125) : Color(red: 0.961, green: 0.961, blue: 0.969)
    }

    static func sidebarBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.157, green: 0.157, blue: 0.176).opacity(0.82)
            : Color(red: 0.961, green: 0.961, blue: 0.969).opacity(0.72)
    }

    static func nowPlayingBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.118, green: 0.118, blue: 0.125).opacity(0.92)
            : Color.white.opacity(0.92)
    }

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.85)
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5)
    }

    static func mutedText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3)
    }

    static func iconColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.45)
    }

    static func borderColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    static func sidebarSelectedBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.09)
    }

    static func sidebarHoverBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    static func rowHoverBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }

    static func trackBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)
    }

    static func volumeFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.45)
    }

    static func searchBackground(for scheme: ColorScheme, focused: Bool) -> Color {
        if focused {
            return scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.07)
        }
        return scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    static func navBackground(for scheme: ColorScheme, active: Bool = false) -> Color {
        if active {
            return scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.07)
        }
        return scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    static func secondaryButtonBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
    }

    static let placeholderGradientColors: [Color] = [
        Color(red: 0.36, green: 0.22, blue: 0.57),
        Color(red: 0.56, green: 0.27, blue: 0.68),
        Color(red: 0.76, green: 0.61, blue: 0.83),
    ]

    // MARK: - Formatting

    static func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
