import XCTest
@testable import Cadence

@MainActor
final class OfflineStoreTests: XCTestCase {

    private var rootDirectory: URL!
    private var sut: OfflineStore!

    override func setUp() async throws {
        try await super.setUp()
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cadence-offline-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        sut = OfflineStore(rootDirectory: rootDirectory)
    }

    override func tearDown() async throws {
        sut = nil
        try? FileManager.default.removeItem(at: rootDirectory)
        rootDirectory = nil
        try await super.tearDown()
    }

    func testLocalURLReturnsNilWhenNotDownloaded() {
        XCTAssertNil(sut.localURL(for: UUID()))
        XCTAssertEqual(sut.state(for: UUID()), .none)
    }

    func testManifestRoundTripRestoresEntries() throws {
        let trackID = UUID()
        let entry = OfflineEntry(
            trackID: trackID,
            jellyfinItemID: "item-1",
            fileName: "\(trackID.uuidString).flac",
            byteSize: 42,
            origin: .manual,
            downloadedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try sut.seedCompletedEntry(entry, fileContents: Data([1, 2, 3, 4]))

        let restored = OfflineStore(rootDirectory: rootDirectory)

        XCTAssertEqual(restored.trackCount, 1)
        XCTAssertEqual(restored.entries[trackID]?.origin, .manual)
        XCTAssertEqual(restored.entries[trackID]?.byteSize, 42)
        XCTAssertEqual(restored.entries[trackID]?.jellyfinItemID, "item-1")
        XCTAssertNotNil(restored.localURL(for: trackID))
        XCTAssertEqual(restored.state(for: trackID), .ready)
    }

    func testRemoveIfFavoriteOriginDeletesOnlyFavorite() throws {
        let favoriteID = UUID()
        let manualID = UUID()

        try sut.seedCompletedEntry(OfflineEntry(
            trackID: favoriteID,
            jellyfinItemID: "fav",
            fileName: "\(favoriteID.uuidString).mp3",
            byteSize: 10,
            origin: .favorite,
            downloadedAt: Date()
        ))
        try sut.seedCompletedEntry(OfflineEntry(
            trackID: manualID,
            jellyfinItemID: "man",
            fileName: "\(manualID.uuidString).mp3",
            byteSize: 20,
            origin: .manual,
            downloadedAt: Date()
        ))

        sut.removeIfFavoriteOrigin(trackID: favoriteID)
        sut.removeIfFavoriteOrigin(trackID: manualID)

        XCTAssertNil(sut.entries[favoriteID])
        XCTAssertNil(sut.localURL(for: favoriteID))
        XCTAssertNotNil(sut.entries[manualID])
        XCTAssertNotNil(sut.localURL(for: manualID))
        XCTAssertEqual(sut.trackCount, 1)
    }

    func testPromoteToManualProtectsFromFavoriteRemoval() throws {
        let trackID = UUID()
        try sut.seedCompletedEntry(OfflineEntry(
            trackID: trackID,
            jellyfinItemID: "item",
            fileName: "\(trackID.uuidString).flac",
            byteSize: 100,
            origin: .favorite,
            downloadedAt: Date()
        ))

        sut.promoteToManual(trackID: trackID)
        XCTAssertEqual(sut.entries[trackID]?.origin, .manual)

        sut.removeIfFavoriteOrigin(trackID: trackID)
        XCTAssertNotNil(sut.entries[trackID])
        XCTAssertEqual(sut.state(for: trackID), .ready)
    }

    func testPruneMissingFilesRemovesOrphanEntries() throws {
        let trackID = UUID()
        let fileName = "\(trackID.uuidString).mp3"
        try sut.seedCompletedEntry(OfflineEntry(
            trackID: trackID,
            jellyfinItemID: nil,
            fileName: fileName,
            byteSize: 5,
            origin: .manual,
            downloadedAt: Date()
        ))

        let fileURL = rootDirectory.appendingPathComponent(fileName)
        try FileManager.default.removeItem(at: fileURL)

        sut.pruneMissingFiles()

        XCTAssertTrue(sut.entries.isEmpty)
        XCTAssertNil(sut.localURL(for: trackID))
        XCTAssertEqual(sut.state(for: trackID), .none)
    }

    func testTotalBytesSumsEntrySizes() throws {
        let a = UUID()
        let b = UUID()
        try sut.seedCompletedEntry(OfflineEntry(
            trackID: a,
            jellyfinItemID: nil,
            fileName: "\(a.uuidString).mp3",
            byteSize: 100,
            origin: .manual,
            downloadedAt: Date()
        ))
        try sut.seedCompletedEntry(OfflineEntry(
            trackID: b,
            jellyfinItemID: nil,
            fileName: "\(b.uuidString).mp3",
            byteSize: 250,
            origin: .favorite,
            downloadedAt: Date()
        ))

        XCTAssertEqual(sut.totalBytes, 350)
        XCTAssertEqual(sut.trackCount, 2)
    }

    func testClearAllRemovesFilesAndManifest() throws {
        let trackID = UUID()
        let fileName = "\(trackID.uuidString).mp3"
        try sut.seedCompletedEntry(OfflineEntry(
            trackID: trackID,
            jellyfinItemID: nil,
            fileName: fileName,
            byteSize: 8,
            origin: .manual,
            downloadedAt: Date()
        ))

        sut.clearAll()

        XCTAssertTrue(sut.entries.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: rootDirectory.appendingPathComponent(fileName).path))
    }

    func testOfflineTracksResolvesOnlyEntriesPresentInLibrary() throws {
        let albumID = UUID()
        let offlineID = UUID()
        let missingID = UUID()
        let remoteURL = URL(string: "https://jellyfin.example/Audio/\(offlineID.uuidString)/universal")!

        try sut.seedCompletedEntry(OfflineEntry(
            trackID: offlineID,
            jellyfinItemID: "item-offline",
            fileName: "\(offlineID.uuidString).flac",
            byteSize: 12,
            origin: .favorite,
            downloadedAt: Date()
        ))
        try sut.seedCompletedEntry(OfflineEntry(
            trackID: missingID,
            jellyfinItemID: "item-missing",
            fileName: "\(missingID.uuidString).flac",
            byteSize: 8,
            origin: .manual,
            downloadedAt: Date()
        ))

        let library = LibraryStore()
        library.loadPreview(result: LibraryScanResult(
            albums: [Album(id: albumID, title: "Album", artist: "Artist")],
            tracks: [
                Track(
                    id: offlineID,
                    index: 1,
                    title: "Offline Track",
                    artist: "Artist",
                    albumID: albumID,
                    duration: 120,
                    fileURL: remoteURL
                )
            ],
            artists: [Artist(name: "Artist", albumIDs: [albumID])]
        ))

        let resolved = sut.offlineTracks(from: library)
        XCTAssertEqual(resolved.map(\.id), [offlineID])
        XCTAssertEqual(resolved.first?.title, "Offline Track")
    }
}
