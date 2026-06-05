import SwiftUI

struct LibraryContentShell<Content: View>: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaylistStore.self) private var playlistStore

    var title: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ContentToolbarView(
                title: title ?? uiState.toolbarTitle(playlistStore: playlistStore)
            )
            content()
        }
    }
}

struct EmptyLibraryStateView: View {
    @Environment(\.colorScheme) private var colorScheme

    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
