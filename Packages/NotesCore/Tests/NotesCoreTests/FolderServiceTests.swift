import XCTest
@testable import NotesCore

@MainActor
final class FolderServiceTests: XCTestCase {

    private func makeService() -> (FolderService, FakeFolderRepository, FakeNoteRepository) {
        let folderRepository = FakeFolderRepository()
        let noteRepository = FakeNoteRepository()
        let service = FolderService(folderRepository: folderRepository, noteRepository: noteRepository)
        return (service, folderRepository, noteRepository)
    }

    func testCreateFolderAssignsIncrementingSortIndex() async throws {
        let (service, _, _) = makeService()
        let workspace = UUID()
        let first = try await service.createFolder(in: workspace)
        let second = try await service.createFolder(in: workspace)
        XCTAssertEqual(first.sortIndex, 0)
        XCTAssertEqual(second.sortIndex, 1)
    }

    func testRenameFolder() async throws {
        let (service, _, _) = makeService()
        let folder = try await service.createFolder(in: UUID())
        let renamed = try await service.rename(folder, to: "資料")
        XCTAssertEqual(renamed.name, "資料")
    }

    func testDeleteFolderRemovesDescendantsAndTrashesNotes() async throws {
        let (service, folderRepository, noteRepository) = makeService()
        let workspace = UUID()

        let parent = try await service.createFolder(in: workspace)
        let child = try await service.createFolder(in: workspace, parentID: parent.id)

        let noteInChild = Note(workspaceID: workspace, folderID: child.id)
        try await noteRepository.save(noteInChild)

        try await service.delete(parent)

        let remainingFolders = try await folderRepository.folders(workspaceID: workspace)
        XCTAssertTrue(remainingFolders.isEmpty)

        let note = try await noteRepository.note(id: noteInChild.id)
        XCTAssertEqual(note?.isTrashed, true)
    }

    func testNestedHierarchyIsQueryable() async throws {
        let (service, _, _) = makeService()
        let workspace = UUID()
        let root = try await service.createFolder(in: workspace)
        _ = try await service.createFolder(in: workspace, parentID: root.id)
        _ = try await service.createFolder(in: workspace, parentID: root.id)

        let folders = try await service.folders(in: workspace)
        let children = folders.filter { $0.parentID == root.id }
        XCTAssertEqual(children.count, 2)
    }
}
