import SwiftUI

struct IOSAlbumView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaybackController.self) private var playbackController
    @Environment(\.colorScheme) private var colorScheme

    let album: Album

    private var tracks: [Track] {
        uiState.tracks(for: album)
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    AlbumCoverView(
                        album: album,
                        size: 220,
                        cornerRadius: 14
                    )
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text(album.title.isEmpty ? "—" : album.title)
                            .font(.system(size: 22, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text(album.artist.isEmpty ? "—" : album.artist)
                            .font(.system(size: 15))
                            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                        Text(metaLine)
                            .font(.system(size: 12))
                            .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                    }

                    HStack(spacing: 12) {
                        Button {
                            playbackController.playAlbum(album, shuffled: false)
                        } label: {
                            Label("Слушать", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            playbackController.playAlbum(album, shuffled: true)
                        } label: {
                            Label("Перемешать", systemImage: "shuffle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        playbackController.play(tracks: tracks, startAt: index, source: .album(album.id))
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(track.index)")
                                .font(.system(size: 13).monospacedDigit())
                                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                                .frame(width: 28, alignment: .trailing)
                            IOSTrackRow(
                                title: track.title,
                                subtitle: track.artist,
                                trailing: CadenceTheme.formatTime(track.duration),
                                isActive: playbackController.playingTrackID == track.id
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(album.title.isEmpty ? "Альбом" : album.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(CadenceTheme.contentBackground(for: colorScheme))
    }

    private var metaLine: String {
        let year = album.year.map(String.init) ?? "—"
        let count = tracks.isEmpty ? "—" : "\(tracks.count) треков"
        let minutes = tracks.isEmpty ? "—" : "\(max(1, Int(tracks.reduce(0) { $0 + $1.duration } / 60))) мин"
        return "\(year) · \(count) · \(minutes)"
    }
}
