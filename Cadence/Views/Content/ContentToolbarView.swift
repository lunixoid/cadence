import SwiftUI

struct ContentToolbarView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(\.colorScheme) private var colorScheme

    var title: String = "Альбомы"

    @FocusState private var isSearchFocused: Bool
    @State private var isBackHovered = false
    @State private var isForwardHovered = false

    private var showsNavigationArrows: Bool { uiState.contentRoute.supportsNavigationArrows }
    private var canGoBack: Bool { uiState.canNavigateBack() }
    private var canGoForward: Bool { uiState.canNavigateForward() }

    var body: some View {
        HStack(spacing: 12) {
            if showsNavigationArrows {
                HStack(spacing: 4) {
                    Button(action: { uiState.navigateBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CadenceTheme.mutedText(for: colorScheme))
                            .frame(width: CadenceTheme.navButtonSize, height: CadenceTheme.navButtonSize)
                            .background(
                                RoundedRectangle(cornerRadius: CadenceTheme.navButtonRadius, style: .continuous)
                                    .fill(
                                        canGoBack && isBackHovered
                                            ? CadenceTheme.navBackground(for: colorScheme, active: true)
                                            : CadenceTheme.navBackground(for: colorScheme)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGoBack)
                    .opacity(canGoBack ? 1 : 0.4)
                    .onHover { isBackHovered = canGoBack && $0 }

                    Button(action: { uiState.navigateForward() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CadenceTheme.mutedText(for: colorScheme))
                            .frame(width: CadenceTheme.navButtonSize, height: CadenceTheme.navButtonSize)
                            .background(
                                RoundedRectangle(cornerRadius: CadenceTheme.navButtonRadius, style: .continuous)
                                    .fill(
                                        canGoForward && isForwardHovered
                                            ? CadenceTheme.navBackground(for: colorScheme, active: true)
                                            : CadenceTheme.navBackground(for: colorScheme)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGoForward)
                    .opacity(canGoForward ? 1 : 0.4)
                    .onHover { isForwardHovered = canGoForward && $0 }
                }
            }

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.02 * 20)
                .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(CadenceTheme.iconColor(for: colorScheme))

                TextField("Поиск", text: Bindable(uiState).searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
            }
            .padding(.horizontal, 10)
            .frame(width: isSearchFocused ? 200 : 160, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(CadenceTheme.searchBackground(for: colorScheme, focused: isSearchFocused))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSearchFocused
                            ? (colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.15))
                            : CadenceTheme.borderColor(for: colorScheme),
                        lineWidth: 0.5
                    )
            )
            .animation(.easeOut(duration: 0.15), value: isSearchFocused)
        }
        .padding(.horizontal, 20)
        .frame(height: CadenceTheme.toolbarHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                .frame(height: 0.5)
        }
    }
}
