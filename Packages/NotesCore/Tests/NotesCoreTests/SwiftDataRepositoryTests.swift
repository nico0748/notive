import SwiftData
import XCTest
@testable import NotesCore

/// SwiftData リポジトリ実装の検証。インメモリストアを用いる。
@MainActor
final class SwiftDataRepositoryTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        return container.mainContext
    }

    func testNoteRepositorySaveAndFetchRoundTrip() async throws {
        let repository = SwiftDataNoteRepository(context: try makeContext())
        let workspace = UUID()
        let note = Note(
            title: "永続化テスト",
            blocks: [
                .heading(HeadingBlock(level: 1, text: "見出し")),
                .code(CodeBlock(language: "swift", code: "let value = 42"))
            ],
            workspaceID: workspace,
            tagIDs: [UUID()]
        )

        try await repository.save(note)
        let fetched = try await repository.note(id: note.id)

        XCTAssertEqual(fetched?.title, "永続化テスト")
        XCTAssertEqual(fetched?.blocks.count, 2)
        XCTAssertEqual(fetched?.tagIDs.count, 1)
    }

    func testNoteRepositoryUpdateOverwritesExisting() async throws {
        let repository = SwiftDataNoteRepository(context: try makeContext())
        var note = Note(title: "初期", workspaceID: UUID())
        try await repository.save(note)

        note.title = "更新済み"
        try await repository.save(note)

        let all = try await repository.allNotes(workspaceID: note.workspaceID)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.title, "更新済み")
    }

    func testNoteRepositoryDelete() async throws {
        let repository = SwiftDataNoteRepository(context: try makeContext())
        let note = Note(title: "削除対象", workspaceID: UUID())
        try await repository.save(note)
        try await repository.delete(id: note.id)
        XCTAssertNil(try await repository.note(id: note.id))
    }

    func testDeleteMissingNoteThrowsNotFound() async throws {
        let repository = SwiftDataNoteRepository(context: try makeContext())
        let missingID = UUID()
        do {
            try await repository.delete(id: missingID)
            XCTFail("notFound エラーが投げられるべき")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .notFound(id: missingID))
        }
    }

    func testFolderRepositoryScopesByWorkspace() async throws {
        let repository = SwiftDataFolderRepository(context: try makeContext())
        let workspaceA = UUID()
        let workspaceB = UUID()
        try await repository.save(Folder(name: "A", workspaceID: workspaceA))
        try await repository.save(Folder(name: "B", workspaceID: workspaceB))

        XCTAssertEqual(try await repository.folders(workspaceID: workspaceA).count, 1)
        XCTAssertEqual(try await repository.folders(workspaceID: workspaceB).count, 1)
    }

    func testUserRepositoryReturnsSavedUser() async throws {
        let repository = SwiftDataUserRepository(context: try makeContext())
        XCTAssertNil(try await repository.currentUser())
        let user = User.makeLocal()
        try await repository.save(user)
        XCTAssertEqual(try await repository.currentUser()?.id, user.id)
    }

    func testWorkspaceRepositoryPersistsKind() async throws {
        let repository = SwiftDataWorkspaceRepository(context: try makeContext())
        let workspace = Workspace.makePersonal(ownerID: UUID())
        try await repository.save(workspace)
        let fetched = try await repository.allWorkspaces().first
        XCTAssertEqual(fetched?.kind, .personal)
    }
}
