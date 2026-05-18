import XCTest
@testable import NotesCore

final class SearchAndWorkspaceTests: XCTestCase {

    func testSearchMatchesTitleAndBody() async throws {
        let repository = FakeNoteRepository()
        let workspace = UUID()
        try await repository.save(Note(
            title: "買い物リスト",
            blocks: [.paragraph(ParagraphBlock(text: "牛乳とパン"))],
            workspaceID: workspace
        ))
        try await repository.save(Note(
            title: "会議メモ",
            blocks: [.paragraph(ParagraphBlock(text: "次回の予定"))],
            workspaceID: workspace
        ))

        let service = SearchService(repository: repository)

        let byTitle = try await service.search(query: "会議", in: workspace)
        XCTAssertEqual(byTitle.count, 1)

        let byBody = try await service.search(query: "牛乳", in: workspace)
        XCTAssertEqual(byBody.count, 1)

        let none = try await service.search(query: "存在しない語", in: workspace)
        XCTAssertTrue(none.isEmpty)
    }

    func testSearchExcludesTrashedByDefault() async throws {
        let repository = FakeNoteRepository()
        let workspace = UUID()
        var trashed = Note(title: "古いメモ", workspaceID: workspace)
        trashed.isTrashed = true
        try await repository.save(trashed)

        let service = SearchService(repository: repository)
        let activeResults = try await service.search(query: "古い", in: workspace)
        XCTAssertTrue(activeResults.isEmpty)
        let allResults = try await service.search(query: "古い", in: workspace, includeTrashed: true)
        XCTAssertEqual(allResults.count, 1)
    }

    func testStartAsLocalUserCreatesUserAndWorkspace() async throws {
        let userRepository = FakeUserRepository()
        let workspaceRepository = FakeWorkspaceRepository()
        let service = WorkspaceService(
            userRepository: userRepository,
            workspaceRepository: workspaceRepository
        )

        let result = try await service.startAsLocalUser()
        XCTAssertTrue(result.user.isLocal)
        XCTAssertEqual(result.workspace.kind, .personal)
        XCTAssertEqual(result.workspace.ownerID, result.user.id)
    }

    func testPersonalWorkspaceIsReusedWhenAlreadyPresent() async throws {
        let userRepository = FakeUserRepository()
        let workspaceRepository = FakeWorkspaceRepository()
        let service = WorkspaceService(
            userRepository: userRepository,
            workspaceRepository: workspaceRepository
        )

        let user = User.makeLocal()
        try await userRepository.save(user)
        let first = try await service.personalWorkspace(for: user)
        let second = try await service.personalWorkspace(for: user)
        XCTAssertEqual(first.id, second.id)
    }
}
