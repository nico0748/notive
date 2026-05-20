import SwiftData
import XCTest
@testable import NotesCore

/// SwiftData リポジトリ実装の検証。インメモリストアを用いる。
///
/// SwiftData の `ModelContext` は `@MainActor` 隔離のため、各テストメソッドを
/// `@MainActor` とする（クラスを `@MainActor` にすると非隔離の `XCTestCase` との
/// 不一致警告が出るため、メソッド単位で付与する）。
///
/// 注意: SwiftData のインメモリ `ModelContainer` は、ホストアプリを持たない
/// ヘッドレスな `swift test`（CI）環境で SIGTRAP クラッシュすることが確認されている。
/// そのため CI 環境ではこれらのテストをスキップし、Xcode 上での実行を前提とする。
/// ドメイン／ユースケースのロジックはインメモリのフェイクリポジトリで別途検証済み。
final class SwiftDataRepositoryTests: XCTestCase {

    /// ヘッドレス CI（GitHub Actions など）で実行中かどうか。
    private var isHeadlessCI: Bool {
        ProcessInfo.processInfo.environment["CI"] != nil
    }

    private func skipIfHeadlessCI() throws {
        try XCTSkipIf(
            isHeadlessCI,
            "SwiftData のインメモリストアはヘッドレス CI (swift test) でクラッシュするため、Xcode 上で実行する"
        )
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        return container.mainContext
    }

    @MainActor
    func testNoteRepositorySaveAndFetchRoundTrip() async throws {
        try skipIfHeadlessCI()
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

    @MainActor
    func testNoteRepositoryUpdateOverwritesExisting() async throws {
        try skipIfHeadlessCI()
        let repository = SwiftDataNoteRepository(context: try makeContext())
        var note = Note(title: "初期", workspaceID: UUID())
        try await repository.save(note)

        note.title = "更新済み"
        try await repository.save(note)

        let all = try await repository.allNotes(workspaceID: note.workspaceID)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.title, "更新済み")
    }

    @MainActor
    func testNoteRepositoryDelete() async throws {
        try skipIfHeadlessCI()
        let repository = SwiftDataNoteRepository(context: try makeContext())
        let note = Note(title: "削除対象", workspaceID: UUID())
        try await repository.save(note)
        try await repository.delete(id: note.id)
        let fetched = try await repository.note(id: note.id)
        XCTAssertNil(fetched)
    }

    @MainActor
    func testDeleteMissingNoteThrowsNotFound() async throws {
        try skipIfHeadlessCI()
        let repository = SwiftDataNoteRepository(context: try makeContext())
        let missingID = UUID()
        do {
            try await repository.delete(id: missingID)
            XCTFail("notFound エラーが投げられるべき")
        } catch let error as RepositoryError {
            XCTAssertEqual(error, .notFound(id: missingID))
        }
    }

    @MainActor
    func testFolderRepositoryScopesByWorkspace() async throws {
        try skipIfHeadlessCI()
        let repository = SwiftDataFolderRepository(context: try makeContext())
        let workspaceA = UUID()
        let workspaceB = UUID()
        try await repository.save(Folder(name: "A", workspaceID: workspaceA))
        try await repository.save(Folder(name: "B", workspaceID: workspaceB))

        let foldersA = try await repository.folders(workspaceID: workspaceA)
        let foldersB = try await repository.folders(workspaceID: workspaceB)
        XCTAssertEqual(foldersA.count, 1)
        XCTAssertEqual(foldersB.count, 1)
    }

    @MainActor
    func testUserRepositoryReturnsSavedUser() async throws {
        try skipIfHeadlessCI()
        let repository = SwiftDataUserRepository(context: try makeContext())
        let before = try await repository.currentUser()
        XCTAssertNil(before)

        let user = User.makeLocal()
        try await repository.save(user)
        let after = try await repository.currentUser()
        XCTAssertEqual(after?.id, user.id)
    }

    @MainActor
    func testWorkspaceRepositoryPersistsKind() async throws {
        try skipIfHeadlessCI()
        let repository = SwiftDataWorkspaceRepository(context: try makeContext())
        let workspace = Workspace.makePersonal(ownerID: UUID())
        try await repository.save(workspace)
        let fetched = try await repository.allWorkspaces().first
        XCTAssertEqual(fetched?.kind, .personal)
    }

    @MainActor
    func testNoteVersionRepositoryRoundTripAndPurge() async throws {
        try skipIfHeadlessCI()
        let repository = SwiftDataNoteVersionRepository(context: try makeContext())
        let noteID = UUID()

        let recent = NoteVersion(
            noteID: noteID,
            capturedAt: .now,
            title: "最新",
            blocks: [.paragraph(ParagraphBlock(text: "本文"))]
        )
        let old = NoteVersion(
            noteID: noteID,
            capturedAt: .now.addingTimeInterval(-31 * 24 * 60 * 60),
            title: "古い",
            blocks: []
        )
        try await repository.save(recent)
        try await repository.save(old)

        let versions = try await repository.versions(noteID: noteID)
        XCTAssertEqual(versions.count, 2)
        XCTAssertEqual(versions.first?.id, recent.id, "新しい順で並ぶ")

        try await repository.purgeExpired(before: .now.addingTimeInterval(-30 * 24 * 60 * 60))
        let remaining = try await repository.versions(noteID: noteID)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, recent.id)
    }
}
