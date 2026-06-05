import SwiftUI

struct OverlayTrafficLights: View {
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            TrafficLightButton(color: Color(red: 1, green: 0.373, blue: 0.341), action: onClose)
            Circle()
                .fill(Color(red: 0.996, green: 0.737, blue: 0.18))
                .frame(width: 11, height: 11)
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                }
            Circle()
                .fill(Color(red: 0.157, green: 0.784, blue: 0.251))
                .frame(width: 11, height: 11)
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                }
        }
    }
}

private struct TrafficLightButton: View {
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 11, height: 11)
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                }
                .scaleEffect(isHovered ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct OverlayTitleBar: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var height: CGFloat = 38
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            OverlayTrafficLights(onClose: onClose)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                .frame(maxWidth: .infinity)
            Color.clear
                .frame(width: 11 * 3 + 6 * 2)
        }
        .padding(.horizontal, 14)
        .frame(height: height)
        .background(CadenceTheme.overlayHeaderBackground(for: colorScheme))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CadenceTheme.borderColor(for: colorScheme))
                .frame(height: 0.5)
        }
    }
}

struct OverlayAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isPresented: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPresented ? 1 : (reduceMotion ? 1 : 0.96))
            .opacity(isPresented ? 1 : 0)
            .offset(y: isPresented ? 0 : (reduceMotion ? 0 : 8))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isPresented)
    }
}

extension View {
    func overlayAppear(isPresented: Bool) -> some View {
        modifier(OverlayAppearModifier(isPresented: isPresented))
    }
}
