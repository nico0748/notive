import XCTest
@testable import NotesCore

/// `NoteVersionService` の挙動を検証する。
final class NoteVersionServiceTests: XCTestCase {

    private func makeService() -> (NoteVersionService, FakeNoteVersionRepository) {
        let repository = FakeNoteVersionRepository()
        return (NoteVersionService(repository: repository), repository)
    }

    func testRecordVersionAddsSnapshot() async throws {
        let (service, _) = makeService()
        let note = Note(title: "メモ", workspaceID: UUID())

        let saved = try await service.recordVersion(of: note)
        XCTAssertNotNil(saved)
        let versions = try await service.versions(of: note.id)
        XCTAssertEqual(versions.count, 1)
        XCTAssertEqual(versions.first?.title, "メモ")
    }

    func testRecordVersionSkipsWhenContentIdentical() async throws {
        let (service, _) = makeService()
        let note = Note(title: "メモ", workspaceID: UUID())

        let first = try await service.recordVersion(of: note, now: Date(timeIntervalSince1970: 0))
        XCTAssertNotNil(first)

        // スロットル時間を十分過ぎても、内容に変化がなければ追加されない。
        let secondAt = Date(timeIntervalSince1970: NotesConstants.VersionHistory.throttle * 2)
        let second = try await service.recordVersion(of: note, now: secondAt)
        XCTAssertNil(second)

        let versions = try await service.versions(of: note.id)
        XCTAssertEqual(versions.count, 1)
    }

    func testRecordVersionWithinThrottleReplacesLatest() async throws {
        let (service, _) = makeService()
        var note = Note(title: "メモ", workspaceID: UUID())

        try await service.recordVersion(of: note, now: Date(timeIntervalSince1970: 0))

        note.title = "メモ（更新）"
        // スロットル時間以内に内容が変化 → 直近の版を上書き。
        try await service.recordVersion(
            of: note,
            now: Date(timeIntervalSince1970: NotesConstants.VersionHistory.throttle / 2)
        )

        let versions = try await service.versions(of: note.id)
        XCTAssertEqual(versions.count, 1)
        XCTAssertEqual(versions.first?.title, "メモ（更新）")
    }

    func testRecordVersionAfterThrottleAppendsNew() async throws {
        let (service, _) = makeService()
        var note = Note(title: "メモ", workspaceID: UUID())

        try await service.recordVersion(of: note, now: Date(timeIntervalSince1970: 0))

        note.title = "メモ（更新）"
        try await service.recordVersion(
            of: note,
            now: Date(timeIntervalSince1970: NotesConstants.VersionHistory.throttle * 2)
        )

        let versions = try await service.versions(of: note.id)
        XCTAssertEqual(versions.count, 2)
        XCTAssertEqual(versions.first?.title, "メモ（更新）", "新しい順で並ぶ")
    }

    func testPurgeExpiredRemovesOldVersions() async throws {
        let (service, repository) = makeService()
        let now = Date()
        let expiry = TimeInterval(NotesConstants.VersionHistory.retentionDays * 24 * 60 * 60)

        let fresh = NoteVersion(noteID: UUID(), capturedAt: now, title: "新しい", blocks: [])
        let stale = NoteVersion(
            noteID: UUID(),
            capturedAt: now.addingTimeInterval(-expiry - 60),
            title: "古い",
            blocks: []
        )
        try await repository.save(fresh)
        try await repository.save(stale)

        try await service.purgeExpired(now: now)

        XCTAssertNotNil(repository.storage[fresh.id])
        XCTAssertNil(repository.storage[stale.id], "保持期間を過ぎた版は削除される")
    }

    func testDeleteAllRemovesVersionsForNote() async throws {
        let (service, repository) = makeService()
        let noteID = UUID()
        let otherID = UUID()

        try await repository.save(NoteVersion(noteID: noteID, title: "a", blocks: []))
        try await repository.save(NoteVersion(noteID: noteID, title: "b", blocks: []))
        try await repository.save(NoteVersion(noteID: otherID, title: "c", blocks: []))

        try await service.deleteAll(of: noteID)

        XCTAssertEqual(try await service.versions(of: noteID).count, 0)
        XCTAssertEqual(try await service.versions(of: otherID).count, 1)
    }
}
