import SwiftUI

struct OverlayTrafficLights: View {
    var onClose: () -> Void

    var body: some View {
        TrafficLightButton(color: Color(red: 1, green: 0.373, blue: 0.341), action: onClose)
    }
}

private struct TrafficLightButton: View {
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 11, height: 11)
            .overlay {
                Circle()
                    .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
            }
            .overlay {
                if isHovered {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
            }
            .scaleEffect(isHovered ? 1.05 : 1)
            .contentShape(Circle())
            .onTapGesture(perform: action)
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
                .frame(width: 11)
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
