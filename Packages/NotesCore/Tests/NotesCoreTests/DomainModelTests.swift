import XCTest
@testable import NotesCore

final class DomainModelTests: XCTestCase {

    func testHeadingBlockClampsLevelToAllowedRange() {
        XCTAssertEqual(HeadingBlock(level: 0).level, NotesConstants.Heading.minLevel)
        XCTAssertEqual(HeadingBlock(level: 99).level, NotesConstants.Heading.maxLevel)
        XCTAssertEqual(HeadingBlock(level: 2).level, 2)
    }

    func testBlockIDMatchesUnderlyingBlock() {
        let paragraph = ParagraphBlock(text: "hello")
        let block = Block.paragraph(paragraph)
        XCTAssertEqual(block.id, paragraph.id)
    }

    func testBlockPlainTextCollectsTextFromEachKind() {
        XCTAssertEqual(Block.heading(HeadingBlock(text: "Title")).plainText, "Title")
        XCTAssertEqual(Block.checklist(ChecklistBlock(items: [
            ChecklistItem(text: "a"), ChecklistItem(text: "b")
        ])).plainText, "a\nb")
        let table = TableBlock(headers: ["H1", "H2"], rows: [["r1", "r2"]])
        XCTAssertTrue(Block.table(table).plainText.contains("r1"))
    }

    func testNoteSearchableTextIncludesTitleAndBody() {
        let note = Note(
            title: "会議メモ",
            blocks: [.paragraph(ParagraphBlock(text: "予算について議論"))],
            workspaceID: UUID()
        )
        XCTAssertTrue(note.searchableText.contains("会議メモ"))
        XCTAssertTrue(note.searchableText.contains("予算"))
    }

    func testNoteMatchesQueryCaseInsensitively() {
        let note = Note(
            title: "Swift Notes",
            blocks: [.paragraph(ParagraphBlock(text: "About SwiftData"))],
            workspaceID: UUID()
        )
        XCTAssertTrue(note.matches(query: "swift"))
        XCTAssertTrue(note.matches(query: "swiftdata"))
        XCTAssertTrue(note.matches(query: "   "))
        XCTAssertFalse(note.matches(query: "kotlin"))
    }

    func testNoteSortingPlacesPinnedFirst() {
        let workspace = UUID()
        let older = Note(title: "A", workspaceID: workspace, createdAt: .now.addingTimeInterval(-100),
                         updatedAt: .now.addingTimeInterval(-100))
        var pinned = Note(title: "B", workspaceID: workspace)
        pinned.isPinned = true
        let sorted = [older, pinned].sorted(by: .updatedDescending)
        XCTAssertEqual(sorted.first?.id, pinned.id)
    }

    func testNoteCodableRoundTrip() throws {
        let note = Note(
            title: "Round Trip",
            blocks: [
                .heading(HeadingBlock(level: 2, text: "Section")),
                .code(CodeBlock(language: "swift", code: "let x = 1")),
                .checklist(ChecklistBlock(items: [ChecklistItem(text: "done", isDone: true)]))
            ],
            workspaceID: UUID()
        )
        let data = try JSONEncoder().encode(note)
        let decoded = try JSONDecoder().decode(Note.self, from: data)
        XCTAssertEqual(decoded, note)
    }

    func testInkBlockCodableRoundTrip() throws {
        let ink = InkBlock(drawingData: Data([0x01, 0x02, 0x03, 0xFF]), height: 320)
        let block = Block.ink(ink)
        let decoded = try JSONDecoder().decode(Block.self, from: JSONEncoder().encode(block))
        XCTAssertEqual(decoded, block)
        XCTAssertEqual(decoded.id, ink.id)
        XCTAssertEqual(decoded.plainText, "")
    }

    func testInkBlockIsEmptyReflectsBothLayers() {
        XCTAssertTrue(InkBlock().isEmpty)
        XCTAssertFalse(InkBlock(drawingData: Data([0x01])).isEmpty)
        XCTAssertFalse(InkBlock(backgroundData: Data([0x01])).isEmpty)
    }

    func testInkBlockRoundTripsLayersAndTemplate() throws {
        let ink = InkBlock(
            drawingData: Data([0x01]),
            backgroundData: Data([0x02, 0x03]),
            template: .cornell,
            height: 300
        )
        let decoded = try JSONDecoder().decode(InkBlock.self, from: JSONEncoder().encode(ink))
        XCTAssertEqual(decoded, ink)
        XCTAssertEqual(decoded.backgroundData, Data([0x02, 0x03]))
        XCTAssertEqual(decoded.template, .cornell)
    }

    /// 旧フォーマット（`backgroundData` / `template` を持たない JSON）も既定値で読める。
    func testInkBlockDecodesLegacyFormat() throws {
        let id = UUID()
        let json = "{\"id\":\"\(id.uuidString)\",\"drawingData\":\"AQID\",\"height\":320}"
        let decoded = try JSONDecoder().decode(InkBlock.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.drawingData, Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(decoded.backgroundData, Data())
        XCTAssertEqual(decoded.template, .blank)
        XCTAssertEqual(decoded.height, 320)
    }
}
