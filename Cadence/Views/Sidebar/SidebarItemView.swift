import SwiftUI

struct SidebarItemView: View {
    @Environment(\.colorScheme) private var colorScheme

    let icon: String
    let label: String
    let isSelected: Bool
    var badge: String?
    var iconColor: Color?
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(resolvedIconColor)
                .frame(width: 15, height: 15)

            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .tracking(-0.01 * 13)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(CadenceTheme.accent(for: colorScheme))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, CadenceTheme.sidebarItemHorizontalPadding)
        .frame(height: CadenceTheme.sidebarItemHeight)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: CadenceTheme.sidebarItemRadius, style: .continuous))
        .padding(.horizontal, CadenceTheme.sidebarItemMargin)
        .contentShape(RoundedRectangle(cornerRadius: CadenceTheme.sidebarItemRadius, style: .continuous))
        .onTapGesture(perform: handleTap)
        .onHover { isHovered = $0 }
    }

    private func handleTap() {
        action()
    }

    private var backgroundColor: Color {
        if isSelected {
            return CadenceTheme.sidebarSelectedBackground(for: colorScheme)
        }
        if isHovered {
            return CadenceTheme.sidebarHoverBackground(for: colorScheme)
        }
        return .clear
    }

    private var textColor: Color {
        if isSelected {
            return CadenceTheme.primaryText(for: colorScheme)
        }
        return colorScheme == .dark ? Color.white.opacity(0.75) : Color.black.opacity(0.75)
    }

    private var resolvedIconColor: Color {
        if let iconColor, isSelected {
            return iconColor
        }
        if isSelected {
            return CadenceTheme.accent(for: colorScheme)
        }
        return CadenceTheme.iconColor(for: colorScheme)
    }
}
