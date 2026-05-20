import XCTest
@testable import NotesCore

final class AppViewModelTests: XCTestCase {

    /// フェイクリポジトリ一式から `AppViewModel` を組み立てるハーネス。
    private struct Harness {
        let appModel: AppViewModel
        let noteRepository: FakeNoteRepository
        let userRepository: FakeUserRepository
        let workspaceRepository: FakeWorkspaceRepository
    }

    @MainActor
    private func makeHarness() -> Harness {
        let userRepository = FakeUserRepository()
        let workspaceRepository = FakeWorkspaceRepository()
        let noteRepository = FakeNoteRepository()
        let folderRepository = FakeFolderRepository()
        let tagRepository = FakeTagRepository()
        let versionRepository = FakeNoteVersionRepository()

        let appModel = AppViewModel(
            noteService: NoteService(repository: noteRepository),
            folderService: FolderService(folderRepository: folderRepository, noteRepository: noteRepository),
            searchService: SearchService(repository: noteRepository),
            tagService: TagService(repository: tagRepository),
            versionService: NoteVersionService(repository: versionRepository),
            workspaceService: WorkspaceService(
                userRepository: userRepository,
                workspaceRepository: workspaceRepository
            )
        )
        return Harness(
            appModel: appModel,
            noteRepository: noteRepository,
            userRepository: userRepository,
            workspaceRepository: workspaceRepository
        )
    }

    @MainActor
    func testBootstrapWithoutUserGoesToLogin() async throws {
        let harness = makeHarness()
        await harness.appModel.bootstrap()
        XCTAssertEqual(harness.appModel.phase, .login)
    }

    @MainActor
    func testStartAsLocalUserBecomesReady() async throws {
        let harness = makeHarness()
        await harness.appModel.startAsLocalUser()
        XCTAssertEqual(harness.appModel.phase, .ready)
        XCTAssertNotNil(harness.appModel.currentWorkspace)
    }

    @MainActor
    func testBootstrapPurgesExpiredTrashedNotes() async throws {
        let harness = makeHarness()

        let user = User.makeLocal()
        try await harness.userRepository.save(user)
        let workspace = Workspace.makePersonal(ownerID: user.id)
        try await harness.workspaceRepository.save(workspace)

        // 保持期間を過ぎたゴミ箱ノート。
        var expired = Note(title: "期限切れ", workspaceID: workspace.id)
        expired.isTrashed = true
        expired.trashedAt = .now.addingTimeInterval(
            -Double(NotesConstants.Trash.retentionDays + 1) * 24 * 60 * 60
        )
        try await harness.noteRepository.save(expired)

        // 通常のノート。
        let active = Note(title: "通常ノート", workspaceID: workspace.id)
        try await harness.noteRepository.save(active)

        await harness.appModel.bootstrap()

        XCTAssertEqual(harness.appModel.phase, .ready)
        let purged = try await harness.noteRepository.note(id: expired.id)
        XCTAssertNil(purged, "期限切れのゴミ箱ノートは起動時に削除されるべき")
        let kept = try await harness.noteRepository.note(id: active.id)
        XCTAssertNotNil(kept, "通常ノートは保持されるべき")
    }
}
