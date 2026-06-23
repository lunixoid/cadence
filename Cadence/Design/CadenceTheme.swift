import SwiftUI

enum CadenceTheme {
    // MARK: - Layout

    static let sidebarWidth: CGFloat = 220
    static let trafficLightsAreaHeight: CGFloat = 52
    static let toolbarHeight: CGFloat = 52
    static let nowPlayingBarHeight: CGFloat = 96
    static let nowPlayingCollapsedBarHeight: CGFloat = 10
    static let nowPlayingHeroCoverSize: CGFloat = 300
    static let nowPlayingRightPanelWidth: CGFloat = 262
    static let nowPlayingWideThreshold: CGFloat = 800
    static let queuePanelWidth: CGFloat = 300
    static let queueHeaderHeight: CGFloat = 52
    static let overlayWindowRadius: CGFloat = 12
    static let eqWindowWidth: CGFloat = 480
    static let eqWindowBottomOffset: CGFloat = 104
    static let eqWindowRightOffset: CGFloat = 20
    static let prefsWindowWidth: CGFloat = 560
    static let prefsWindowHeight: CGFloat = 460
    static let connectWindowWidth: CGFloat = 420
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

    static let volumeSliderWidth: CGFloat = 100
    static let volumeSliderHeight: CGFloat = 4

    static let miniCoverSize: CGFloat = 56
    static let miniCoverRadius: CGFloat = 8
    static let playButtonSize: CGFloat = 56
    static let transportButtonSize: CGFloat = 44
    static let playerIconButtonSize: CGFloat = 40
    static let queueCoverSize: CGFloat = 32
    static let queueNowPlayingCoverSize: CGFloat = 40
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

    // MARK: - Preferences (theme-aware)

    static func prefsBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.173, green: 0.173, blue: 0.180)
            : Color(red: 0.965, green: 0.965, blue: 0.973)
    }

    static func prefsToolbarBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.157, green: 0.157, blue: 0.165).opacity(0.97)
            : Color(red: 0.941, green: 0.941, blue: 0.957).opacity(0.97)
    }

    static func prefsCardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.227, green: 0.227, blue: 0.235) : Color.white
    }

    static func prefsText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.88) : Color.black.opacity(0.86)
    }

    static func prefsSubtext(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.42)
    }

    static func prefsMuted(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.28)
    }

    static func prefsBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.1)
    }

    static func prefsAccent(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.039, green: 0.518, blue: 1.0)
            : Color(red: 0, green: 0.478, blue: 1.0)
    }

    static func prefsSelectionBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.039, green: 0.518, blue: 1.0).opacity(0.18)
            : Color(red: 0, green: 0.478, blue: 1.0).opacity(0.09)
    }

    static func prefsSegmentBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.118, green: 0.118, blue: 0.125) : Color.black.opacity(0.07)
    }

    static func prefsSegmentButtonSelected(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.282, green: 0.282, blue: 0.290) : Color.white
    }

    static func prefsToggleTrack(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.16)
    }

    static func prefsSliderTrack(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.1)
    }

    static func queuePanelBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.141, green: 0.141, blue: 0.157).opacity(0.9)
            : Color(red: 0.969, green: 0.969, blue: 0.976).opacity(0.9)
    }

    static func overlayWindowBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.141, green: 0.141, blue: 0.157).opacity(0.97)
            : Color(red: 0.98, green: 0.98, blue: 0.988).opacity(0.97)
    }

    static func overlayHeaderBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.025)
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
