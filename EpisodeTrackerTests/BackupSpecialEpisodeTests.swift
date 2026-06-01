import XCTest
@testable import EpisodeTracker

final class BackupSpecialEpisodeTests: XCTestCase {
    func testBackupRoundTripPreservesSpecial() throws {
        let payload = BackupPayload(
            exportedAt: .now,
            schemaVersion: 2,
            collections: nil,
            moods: [],
            episodes: [
                BackupEpisode(
                    episodeNumber: 0,
                    kind: .special,
                    catalogSlug: "phantomsee-2024",
                    title: "Phantomsee",
                    releaseYear: 2024,
                    personalNote: nil,
                    isListened: false,
                    rating: nil,
                    listenCount: 0,
                    lastListenedAt: nil,
                    collectionName: "Die drei ???",
                    moodNames: []
                )
            ]
        )

        let data = try JSONEncoder.backupEncoder.encode(payload)
        let decoded = try JSONDecoder.backupDecoder.decode(BackupPayload.self, from: data)

        XCTAssertEqual(decoded.episodes.first?.kind, .special)
        XCTAssertEqual(decoded.episodes.first?.catalogSlug, "phantomsee-2024")
    }

    func testOldBackupWithoutKindDecodesAsRegular() throws {
        let json = """
        {"exportedAt":"2024-01-01T00:00:00Z","schemaVersion":1,"moods":[],"episodes":[{"episodeNumber":42,"title":"A","releaseYear":2020,"isListened":false,"listenCount":0,"moodNames":[]}]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder.backupDecoder.decode(BackupPayload.self, from: json)
        XCTAssertEqual(decoded.episodes.first?.kind, .regular)
        XCTAssertNil(decoded.episodes.first?.catalogSlug)
    }
}
