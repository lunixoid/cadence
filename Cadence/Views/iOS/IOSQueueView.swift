import SwiftUI

struct IOSQueueView: View {
    @Environment(PlaybackController.self) private var playbackController
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var upNext: [Track] {
        playbackController.upNextTracks
    }

    private var autoplay: [Track] {
        playbackController.autoplayPreviewTracks()
    }

    var body: some View {
        NavigationStack {
            List {
                if let current = playbackController.currentTrack {
                    Section("Сейчас") {
                        queueRow(current, isCurrent: true) {
                            // already playing
                        }
                    }
                }

                if !autoplay.isEmpty {
                    Section("Далее из альбома") {
                        ForEach(Array(autoplay.enumerated()), id: \.element.id) { _, track in
                            queueRow(track, isCurrent: false) {
                                playbackController.playTrack(track)
                            }
                        }
                    }
                }

                Section("В очереди") {
                    if upNext.isEmpty {
                        Text("Очередь пуста")
                            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                    } else {
                        ForEach(Array(upNext.enumerated()), id: \.element.id) { index, track in
                            queueRow(track, isCurrent: false) {
                                playbackController.playUpNext(at: index)
                            }
                        }
                        .onMove { source, destination in
                            guard let from = source.first else { return }
                            var to = destination
                            if from < to { to -= 1 }
                            playbackController.moveUpNextItem(from: from, to: to)
                        }
                    }
                }
            }
            .navigationTitle("Список воспроизведения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func queueRow(_ track: Track, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AlbumCoverView(
                    album: libraryStore.album(for: track.albumID),
                    size: 40,
                    cornerRadius: 6
                )
                IOSTrackRow(
                    title: track.title,
                    subtitle: track.artist,
                    trailing: CadenceTheme.formatTime(track.duration),
                    isActive: isCurrent
                )
            }
        }
        .buttonStyle(.plain)
    }
}
