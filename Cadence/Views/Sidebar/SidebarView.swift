import AppKit
import SwiftUI

struct SidebarView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var showCreatePlaylistAlert = false
    @State private var newPlaylistName = ""

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar)
                .overlay {
                    CadenceTheme.sidebarBackground(for: colorScheme)
                }

            VStack(spacing: 0) {
                WindowDragRegion()
                    .frame(height: CadenceTheme.trafficLightsAreaHeight)

                ScrollView {
                    VStack(spacing: 1) {
                        SidebarItemView(
                            icon: SidebarItem.nowPlaying.icon,
                            label: SidebarItem.nowPlaying.label,
                            isSelected: uiState.activeSidebarItem == .nowPlaying,
                            action: { uiState.selectSidebarItem(.nowPlaying) }
                        )
                        .padding(.bottom, 4)

                        sidebarDivider

                        SidebarSectionHeader(title: "Библиотека")
                        ForEach(SidebarItem.libraryItems) { item in
                            SidebarItemView(
                                icon: item.icon,
                                label: item.label,
                                isSelected: uiState.activeSidebarItem == item,
                                action: { uiState.selectSidebarItem(item) }
                            )
                        }

                        sidebarDivider
                            .padding(.top, 8)

                        SidebarSectionHeader(title: "Плейлисты")
                        ForEach(playlistStore.playlists) { playlist in
                            SidebarItemView(
                                icon: "music.note.list",
                                label: playlist.name,
                                isSelected: {
                                    if case .playlistDetail(let id) = uiState.contentRoute {
                                        return id == playlist.id
                                    }
                                    return false
                                }(),
                                action: { uiState.selectPlaylist(playlist) }
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    deletePlaylist(playlist)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }

                        createPlaylistButton

                        sidebarDivider
                            .padding(.top, 8)

                        ForEach(SidebarItem.extraItems) { item in
                            SidebarItemView(
                                icon: item.icon,
                                label: item.label,
                                isSelected: uiState.activeSidebarItem == item,
                                badge: item == .downloaded && uiState.downloadedCount > 0
                                    ? "\(uiState.downloadedCount)" : nil,
                                iconColor: item.selectedIconColor,
                                action: { uiState.selectSidebarItem(item) }
                            )
                        }
                    }
                    .padding(.bottom, 12)
                }

                settingsButton
            }
        }
        .frame(width: CadenceTheme.sidebarWidth)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(CadenceTheme.borderColor(for: colorScheme))
                .frame(width: 0.5)
        }
        .alert("Новый плейлист", isPresented: $showCreatePlaylistAlert) {
            TextField("Название", text: $newPlaylistName)
            Button("Создать") {
                let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let playlist = playlistStore.createPlaylist(name: name)
                newPlaylistName = ""
                uiState.selectPlaylist(playlist)
            }
            Button("Отмена", role: .cancel) {
                newPlaylistName = ""
            }
        } message: {
            Text("Введите название плейлиста")
        }
    }

    private func deletePlaylist(_ playlist: Playlist) {
        if case .playlistDetail(let id) = uiState.contentRoute, id == playlist.id {
            uiState.selectSidebarItem(.tracks)
        }
        playlistStore.deletePlaylist(id: playlist.id)
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(CadenceTheme.borderColor(for: colorScheme))
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    @State private var isSettingsHovered = false

    private var settingsButton: some View {
        Button(action: { uiState.openPreferences() }) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                Text("Настройки")
                    .font(.system(size: 12))
            }
            .foregroundStyle(
                isSettingsHovered
                    ? CadenceTheme.secondaryText(for: colorScheme)
                    : CadenceTheme.mutedText(for: colorScheme)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CadenceTheme.sidebarItemMargin)
            .frame(height: CadenceTheme.sidebarItemHeight)
            .background(
                isSettingsHovered
                    ? CadenceTheme.sidebarHoverBackground(for: colorScheme)
                    : .clear
            )
            .clipShape(RoundedRectangle(cornerRadius: CadenceTheme.sidebarItemRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: CadenceTheme.sidebarItemRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isSettingsHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSettingsHovered)
        .padding(.horizontal, 0)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CadenceTheme.borderColor(for: colorScheme))
                .frame(height: 0.5)
        }
    }

    private var createPlaylistButton: some View {
        Button(action: { showCreatePlaylistAlert = true }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 13))
                Text("Создать плейлист")
                    .font(.system(size: 12))
            }
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.35))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CadenceTheme.sidebarItemMargin)
        }
        .buttonStyle(.plain)
    }
}
