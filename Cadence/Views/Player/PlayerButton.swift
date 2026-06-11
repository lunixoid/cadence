import SwiftUI

struct PlayerButton<Label: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    var size: CGFloat = 28
    var isActive = false
    var action: () -> Void = {}
    @ViewBuilder var label: () -> Label

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .bottom) {
            label()
                .foregroundStyle(foregroundColor)
                .scaleEffect(isHovered ? 1.08 : 1)

            if isActive {
                Circle()
                    .fill(CadenceTheme.accent(for: colorScheme))
                    .frame(width: 4, height: 4)
                    .offset(y: 6)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .onTapGesture(perform: action)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var foregroundColor: Color {
        if isActive {
            return CadenceTheme.accent(for: colorScheme)
        }
        if isHovered {
            return CadenceTheme.primaryText(for: colorScheme)
        }
        return CadenceTheme.iconColor(for: colorScheme)
    }
}
