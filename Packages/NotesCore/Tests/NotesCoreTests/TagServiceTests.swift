import XCTest
@testable import NotesCore

final class TagServiceTests: XCTestCase {

    func testCreateTagPersists() async throws {
        let repository = FakeTagRepository()
        let service = TagService(repository: repository)
        let workspace = UUID()

        let tag = try await service.createTag(name: "重要", in: workspace)
        XCTAssertEqual(tag.name, "重要")
        XCTAssertEqual(tag.workspaceID, workspace)

        let tags = try await service.tags(in: workspace)
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags.first?.id, tag.id)
    }

    func testTagsScopedToWorkspace() async throws {
        let repository = FakeTagRepository()
        let service = TagService(repository: repository)
        let workspaceA = UUID()
        let workspaceB = UUID()

        _ = try await service.createTag(name: "A1", in: workspaceA)
        _ = try await service.createTag(name: "A2", in: workspaceA)
        _ = try await service.createTag(name: "B1", in: workspaceB)

        let tagsA = try await service.tags(in: workspaceA)
        let tagsB = try await service.tags(in: workspaceB)
        XCTAssertEqual(tagsA.count, 2)
        XCTAssertEqual(tagsB.count, 1)
    }

    func testDeleteTag() async throws {
        let repository = FakeTagRepository()
        let service = TagService(repository: repository)
        let workspace = UUID()

        let tag = try await service.createTag(name: "一時タグ", in: workspace)
        try await service.delete(tag)

        let tags = try await service.tags(in: workspace)
        XCTAssertTrue(tags.isEmpty)
    }

    func testPaletteColorCyclesThroughPalette() {
        XCTAssertFalse(Tag.palette.isEmpty)
        XCTAssertEqual(Tag.paletteColor(forIndex: 0), Tag.palette[0])
        XCTAssertEqual(Tag.paletteColor(forIndex: Tag.palette.count), Tag.palette[0])
        XCTAssertEqual(Tag.paletteColor(forIndex: 1), Tag.palette[1])
    }
}
