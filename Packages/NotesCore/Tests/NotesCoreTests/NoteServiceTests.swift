import XCTest
@testable import NotesCore

@MainActor
final class NoteServiceTests: XCTestCase {

    private func makeService() -> (NoteService, FakeNoteRepository) {
        let repository = FakeNoteRepository()
        return (NoteService(repository: repository), repository)
    }

    func testCreateNotePersistsNote() async throws {
        let (service, repository) = makeService()
        let workspace = UUID()
        let note = try await service.createNote(in: workspace)
        XCTAssertNotNil(repository.storage[note.id])
        XCTAssertEqual(note.workspaceID, workspace)
    }

    func testSaveUpdatesTimestamp() async throws {
        let (service, _) = makeService()
        var note = try await service.createNote(in: UUID())
        let original = note.updatedAt
        note.title = "更新後"
        try await Task.sleep(for: .milliseconds(10))
        let saved = try await service.save(note)
        XCTAssertGreaterThan(saved.updatedAt, original)
        XCTAssertEqual(saved.title, "更新後")
    }

    func testMoveToTrashAndRestore() async throws {
        let (service, _) = makeService()
        let note = try await service.createNote(in: UUID())

        let trashed = try await service.moveToTrash(note)
        XCTAssertTrue(trashed.isTrashed)
        XCTAssertNotNil(trashed.trashedAt)

        let restored = try await service.restoreFromTrash(trashed)
        XCTAssertFalse(restored.isTrashed)
        XCTAssertNil(restored.trashedAt)
    }

    func testActiveNotesFilterByFolder() async throws {
        let (service, _) = makeService()
        let workspace = UUID()
        let folder = UUID()
        _ = try await service.createNote(in: workspace, folderID: folder)
        _ = try await service.createNote(in: workspace, folderID: nil)

        let inFolder = try await service.activeNotes(in: workspace, folderID: folder)
        XCTAssertEqual(inFolder.count, 1)

        let unfiled = try await service.activeNotes(in: workspace, folderID: nil)
        XCTAssertEqual(unfiled.count, 1)
    }

    func testDeletePermanentlyRemovesNote() async throws {
        let (service, repository) = makeService()
        let note = try await service.createNote(in: UUID())
        try await service.deletePermanently(note)
        XCTAssertNil(repository.storage[note.id])
    }

    func testPurgeExpiredTrashRemovesOldNotesOnly() async throws {
        let (service, repository) = makeService()
        let workspace = UUID()

        var recent = try await service.createNote(in: workspace)
        recent = try await service.moveToTrash(recent)

        var stale = try await service.createNote(in: workspace)
        stale.isTrashed = true
        stale.trashedAt = .now.addingTimeInterval(-Double(NotesConstants.Trash.retentionDays + 1) * 86_400)
        try await service.save(stale)

        try await service.purgeExpiredTrash(in: workspace)

        XCTAssertNotNil(repository.storage[recent.id])
        XCTAssertNil(repository.storage[stale.id])
    }
}
