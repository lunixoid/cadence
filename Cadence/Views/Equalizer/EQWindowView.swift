import SwiftUI

enum EQBand: String, CaseIterable, Identifiable {
    case hz32 = "32"
    case hz64 = "64"
    case hz125 = "125"
    case hz250 = "250"
    case hz500 = "500"
    case k1 = "1K"
    case k2 = "2K"
    case k4 = "4K"
    case k8 = "8K"
    case k16 = "16K"

    var id: String { rawValue }
}

enum EQPreset: String, CaseIterable, Identifiable {
    case flat = "Flat"
    case rock = "Rock"
    case pop = "Pop"
    case jazz = "Jazz"
    case classical = "Classical"
    case electronic = "Electronic"
    case hipHop = "Hip-Hop"
    case acoustic = "Acoustic"
    case bassBoost = "Bass Boost"
    case vocalBoost = "Vocal Boost"
    case custom = "Custom"

    var id: String { rawValue }

    var gains: [Double] {
        switch self {
        case .flat: return Array(repeating: 0, count: 10)
        case .rock: return [6, 5, 3, 0, -2, -3, -2, 1, 4, 5]
        case .pop: return [-1, 0, 2, 3, 2, 0, -1, -1, 0, 0]
        case .jazz: return [3, 2, 1, 2, -2, -2, 0, 1, 2, 3]
        case .classical: return [4, 3, 2, 1, -2, -2, 0, 2, 3, 4]
        case .electronic: return [5, 4, 1, 0, -3, -4, -2, 1, 4, 5]
        case .hipHop: return [5, 4, 1, 1, -2, -2, -1, 1, 2, 1]
        case .acoustic: return [3, 2, 2, 1, 1, 0, 0, 1, 1, 2]
        case .bassBoost: return [6, 5, 4, 2, 0, -1, -1, 0, 0, 0]
        case .vocalBoost: return [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1]
        case .custom: return Array(repeating: 0, count: 10)
        }
    }

    static func matching(gains: [Double]) -> EQPreset {
        allCases.first { $0 != .custom && $0.gains == gains } ?? .custom
    }
}

struct EQWindowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(PlaybackController.self) private var playbackController

    let isOpen: Bool
    let onClose: () -> Void

    private let minGain: Double = -12
    private let maxGain: Double = 12
    private let trackHeight: CGFloat = 150

    private var selectedPreset: EQPreset {
        EQPreset.matching(gains: playbackController.eqGains)
    }

    var body: some View {
        if isOpen {
            VStack(spacing: 0) {
                OverlayTitleBar(title: "Эквалайзер", onClose: onClose)

                controlsRow

                slidersArea
            }
            .frame(width: CadenceTheme.eqWindowWidth)
            .background {
                VisualEffectBackground(material: .hudWindow)
                    .overlay {
                        CadenceTheme.overlayWindowBackground(for: colorScheme)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: CadenceTheme.overlayWindowRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CadenceTheme.overlayWindowRadius, style: .continuous)
                    .stroke(CadenceTheme.borderColor(for: colorScheme), lineWidth: 0.5)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.45 : 0.13),
                radius: 24,
                y: 12
            )
            .overlayAppear(isPresented: isOpen)
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            EQToggle(isOn: playbackController.eqEnabled) {
                playbackController.eqEnabled.toggle()
            }

            Picker("Пресет", selection: Binding(
                get: { selectedPreset },
                set: { preset in
                    guard preset != .custom else { return }
                    for (i, gain) in preset.gains.enumerated() {
                        playbackController.setEQGain(at: i, gain: gain)
                    }
                }
            )) {
                ForEach(EQPreset.allCases.filter { $0 != .custom }) { preset in
                    Text(preset.rawValue).tag(preset)
                }
                if selectedPreset == .custom {
                    Text("Custom").tag(EQPreset.custom)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            .disabled(!playbackController.eqEnabled)
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CadenceTheme.borderColor(for: colorScheme))
                .frame(height: 0.5)
        }
    }

    private var slidersArea: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack {
                ForEach(["+12", "+6", "0", "-6", "-12"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 24, height: trackHeight + 26)
            .padding(.top, 13)
            .padding(.trailing, 6)

            HStack(spacing: 0) {
                ForEach(Array(EQBand.allCases.enumerated()), id: \.element.id) { index, band in
                    EQSliderView(
                        value: playbackController.eqGains[index],
                        bandLabel: band.rawValue,
                        minGain: minGain,
                        maxGain: maxGain,
                        trackHeight: trackHeight,
                        isEnabled: playbackController.eqEnabled,
                        onChange: { newValue in
                            playbackController.setEQGain(at: index, gain: newValue)
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .opacity(playbackController.eqEnabled ? 1 : 0.38)
        .allowsHitTesting(playbackController.eqEnabled)
        .animation(.easeOut(duration: 0.2), value: playbackController.eqEnabled)
    }
}

private struct EQToggle: View {
    @Environment(\.colorScheme) private var colorScheme

    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? CadenceTheme.accent(for: colorScheme) : CadenceTheme.trackBackground(for: colorScheme))
                    .frame(width: 38, height: 22)

                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isOn)
    }
}

private struct EQSliderView: View {
    @Environment(\.colorScheme) private var colorScheme

    let value: Double
    let bandLabel: String
    let minGain: Double
    let maxGain: Double
    let trackHeight: CGFloat
    let isEnabled: Bool
    let onChange: (Double) -> Void

    @State private var isHovered = false

    private var displayValue: String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(displayValue)
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(value == 0 ? CadenceTheme.secondaryText(for: colorScheme) : CadenceTheme.accent(for: colorScheme))
                .frame(minWidth: 30)

            GeometryReader { geometry in
                let width = geometry.size.width
                let handleY = yPosition(for: value, in: trackHeight)

                ZStack(alignment: .top) {
                    Capsule()
                        .fill(CadenceTheme.trackBackground(for: colorScheme))
                        .frame(width: 3, height: trackHeight)
                        .position(x: width / 2, y: trackHeight / 2)

                    if value != 0 {
                        let fillTop = value >= 0 ? handleY : trackHeight / 2
                        let fillHeight = abs(value) / (maxGain - minGain) * trackHeight
                        Capsule()
                            .fill(CadenceTheme.accent(for: colorScheme).opacity(isEnabled ? 0.8 : 0.4))
                            .frame(width: 3, height: max(fillHeight, 1))
                            .position(x: width / 2, y: fillTop + fillHeight / 2)
                    }

                    Rectangle()
                        .fill(CadenceTheme.secondaryText(for: colorScheme).opacity(0.5))
                        .frame(width: 9, height: 1.5)
                        .position(x: width / 2, y: trackHeight / 2)

                    Circle()
                        .fill(.white)
                        .overlay {
                            Circle()
                                .stroke(CadenceTheme.accent(for: colorScheme), lineWidth: 2)
                        }
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                        .scaleEffect(isHovered ? 1.08 : 1)
                        .position(x: width / 2, y: handleY)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            onChange(gain(for: gesture.location.y))
                        }
                )
            }
            .frame(height: trackHeight)

            Text(bandLabel)
                .font(.system(size: 10))
                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
        }
    }

    private func yPosition(for gain: Double, in height: CGFloat) -> CGFloat {
        let ratio = (gain - minGain) / (maxGain - minGain)
        return height - CGFloat(ratio) * height
    }

    private func gain(for y: CGFloat) -> Double {
        let clampedY = min(max(y, 0), trackHeight)
        let ratio = 1 - Double(clampedY / trackHeight)
        let raw = minGain + ratio * (maxGain - minGain)
        return Double(Int(raw.rounded()))
    }
}
