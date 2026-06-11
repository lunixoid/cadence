import SwiftUI
import UniformTypeIdentifiers

struct QueuePanelView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(PlaybackController.self) private var playbackController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isOpen: Bool

    @State private var dragSourceIndex: Int?
    @State private var dragOverIndex: Int?

    private var upNextTracks: [Track] {
        playbackController.upNextTracks
    }

    private var autoplayTracks: [Track] {
        playbackController.autoplayPreviewTracks()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if isOpen {
                panelContent
                    .frame(width: CadenceTheme.queuePanelWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: isOpen ? CadenceTheme.queuePanelWidth : 0)
        .clipped()
        .overlay(alignment: .leading) {
            if isOpen {
                Rectangle()
                    .fill(CadenceTheme.borderColor(for: colorScheme))
                    .frame(width: 0.5)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: isOpen)
    }

    private var panelContent: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow)
                .overlay {
                    CadenceTheme.queuePanelBackground(for: colorScheme)
                }

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        QueueSectionHeader(title: "Сейчас играет")

                        if let track = playbackController.currentTrack {
                            QueueTrackRowView(
                                track: track,
                                album: playbackController.album(),
                                isNowPlaying: true
                            )
                        } else {
                            emptyRow(text: "Нет трека")
                        }

                        sectionDivider

                        QueueSectionHeader(
                            title: "Далее",
                            actionTitle: upNextTracks.isEmpty ? nil : "Очистить",
                            onAction: { playbackController.clearUpNext() }
                        )

                        if upNextTracks.isEmpty {
                            emptyRow(text: "Нет треков", italic: true)
                        } else {
                            ForEach(Array(upNextTracks.enumerated()), id: \.element.id) { index, track in
                                QueueTrackRowView(
                                    track: track,
                                    album: playbackController.album(forCurrentTrack: track),
                                    showDragHandle: true,
                                    isDragOver: dragOverIndex == index && dragSourceIndex != index,
                                    removable: true
                                )
                                .onDrag {
                                    dragSourceIndex = index
                                    return NSItemProvider(object: "\(index)" as NSString)
                                }
                                .onDrop(
                                    of: [UTType.plainText],
                                    delegate: QueueDropDelegate(
                                        targetIndex: index,
                                        dragSourceIndex: $dragSourceIndex,
                                        dragOverIndex: $dragOverIndex,
                                        onMove: { source, destination in
                                            playbackController.moveUpNextItem(from: source, to: destination)
                                        }
                                    )
                                )
                            }
                        }

                        sectionDivider

                        QueueSectionHeader(title: "Автовоспроизведение")

                        if autoplayTracks.isEmpty {
                            emptyRow(text: "Нет треков", italic: true)
                        } else {
                            ForEach(autoplayTracks) { track in
                                QueueTrackRowView(
                                    track: track,
                                    album: playbackController.album(forCurrentTrack: track),
                                    dimmed: true
                                )
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Очередь")
                .font(.system(size: 15, weight: .bold))
                .kerning(-0.015 * 15)
                .foregroundStyle(CadenceTheme.primaryText(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WindowDragRegion())

            Spacer()

            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CadenceTheme.iconColor(for: colorScheme))
                .frame(width: 22, height: 22)
                .background(CadenceTheme.secondaryButtonBackground(for: colorScheme))
                .clipShape(Circle())
                .contentShape(Circle())
                .onTapGesture {
                    uiState.isQueueOpen = false
                }
        }
        .padding(.horizontal, 16)
        .padding(.trailing, 4)
        .frame(height: CadenceTheme.queueHeaderHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CadenceTheme.borderColor(for: colorScheme))
                .frame(height: 0.5)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(CadenceTheme.borderColor(for: colorScheme).opacity(0.85))
            .frame(height: 1)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }

    private func emptyRow(text: String, italic: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 12))
            .italic(italic)
            .foregroundStyle(CadenceTheme.mutedText(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
    }
}

private struct QueueSectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var actionTitle: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(0.05 * 11)
                .foregroundStyle(CadenceTheme.mutedText(for: colorScheme))

            Spacer()

            if let actionTitle, let onAction {
                Text(actionTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CadenceTheme.accent(for: colorScheme))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onAction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 5)
    }
}

private struct QueueTrackRowView: View {
    @Environment(PlaybackController.self) private var playbackController
    @Environment(\.colorScheme) private var colorScheme

    let track: Track
    let album: Album?
    var isNowPlaying = false
    var showDragHandle = false
    var dimmed = false
    var isDragOver = false
    var removable = false

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if showDragHandle {
                dragHandle
            } else if !isNowPlaying {
                Color.clear.frame(width: 12)
            }

            AlbumCoverView(
                album: album,
                size: isNowPlaying ? CadenceTheme.queueNowPlayingCoverSize : CadenceTheme.queueCoverSize,
                cornerRadius: 5
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.system(size: 12, weight: isNowPlaying ? .semibold : .regular))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 11))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text("×")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CadenceTheme.secondaryText(for: colorScheme))
                .frame(width: 18, height: 18)
                .background(CadenceTheme.secondaryButtonBackground(for: colorScheme))
                .clipShape(Circle())
                .contentShape(Circle())
                .opacity(removable && isHovered ? 1 : 0)
                .allowsHitTesting(removable && isHovered)
                .onTapGesture(perform: removeFromQueue)
        }
        .id(track.id)
        .padding(.vertical, isNowPlaying ? 6 : 4)
        .padding(.leading, showDragHandle ? 8 : 12)
        .padding(.trailing, 12)
        .padding(.horizontal, 4)
        .background(backgroundColor)
        .overlay(alignment: .top) {
            if isDragOver {
                Rectangle()
                    .fill(CadenceTheme.accent(for: colorScheme))
                    .frame(height: 1.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isDragOver)
    }

    private func removeFromQueue() {
        playbackController.removeFromUpNext(trackID: track.id)
    }

    private var dragHandle: some View {
        VStack(spacing: 2.5) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .fill(colorScheme == .dark ? Color.white : Color.black)
                    .frame(width: 10, height: 1.5)
            }
        }
        .frame(width: 12, height: 12)
        .opacity(isHovered ? 0.55 : 0.18)
    }

    private var titleColor: Color {
        if isNowPlaying {
            return CadenceTheme.accent(for: colorScheme)
        }
        if dimmed {
            return CadenceTheme.primaryText(for: colorScheme).opacity(0.42)
        }
        return CadenceTheme.primaryText(for: colorScheme)
    }

    private var subtitleColor: Color {
        if dimmed {
            return CadenceTheme.secondaryText(for: colorScheme).opacity(0.5)
        }
        return CadenceTheme.secondaryText(for: colorScheme)
    }

    private var backgroundColor: Color {
        if isDragOver {
            return CadenceTheme.accent(for: colorScheme).opacity(colorScheme == .dark ? 0.1 : 0.07)
        }
        if isHovered {
            return CadenceTheme.rowHoverBackground(for: colorScheme)
        }
        return .clear
    }
}

private struct QueueDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var dragSourceIndex: Int?
    @Binding var dragOverIndex: Int?
    let onMove: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        dragOverIndex = targetIndex
    }

    func dropExited(info: DropInfo) {
        if dragOverIndex == targetIndex {
            dragOverIndex = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let source = dragSourceIndex else { return false }
        onMove(source, targetIndex)
        dragSourceIndex = nil
        dragOverIndex = nil
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        true
    }
}
