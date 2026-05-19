import XCTest
@testable import NotesCore

final class EditorViewModelTests: XCTestCase {

    @MainActor
    private func makeEditor() -> (EditorViewModel, FakeNoteRepository) {
        let noteRepository = FakeNoteRepository()
        let editor = EditorViewModel(
            noteService: NoteService(repository: noteRepository),
            tagService: TagService(repository: FakeTagRepository())
        )
        return (editor, noteRepository)
    }

    @MainActor
    func testAddAndUpdateInkBlock() async throws {
        let (editor, repository) = makeEditor()
        let note = Note(title: "手書き", workspaceID: UUID())
        try await repository.save(note)
        await editor.open(note)

        let inkID = editor.addInkBlock()
        XCTAssertNotNil(editor.inkBlock(id: inkID))
        XCTAssertEqual(editor.inkBlock(id: inkID)?.isEmpty, true)

        editor.updateInkBlock(id: inkID, drawingData: Data([0x09, 0x09]))
        XCTAssertEqual(editor.inkBlock(id: inkID)?.drawingData, Data([0x09, 0x09]))
    }

    @MainActor
    func testInkBlockSurvivesMarkdownRoundTrip() async throws {
        let (editor, repository) = makeEditor()
        let ink = InkBlock(drawingData: Data([0x01, 0x02, 0x03, 0x04]))
        let note = Note(
            title: "混在ノート",
            blocks: [
                .paragraph(ParagraphBlock(text: "前文")),
                .ink(ink),
                .paragraph(ParagraphBlock(text: "後文"))
            ],
            workspaceID: UUID()
        )
        try await repository.save(note)
        await editor.open(note)

        // リッチ → Markdown: 手書きはマーカーとして表現される。
        editor.toggleMarkdownMode()
        XCTAssertTrue(editor.isMarkdownMode)
        XCTAssertTrue(editor.markdownText.contains("notive-ink:\(ink.id.uuidString)"))

        // Markdown → リッチ: 手書きの実データが復元される。
        editor.toggleMarkdownMode()
        XCTAssertFalse(editor.isMarkdownMode)

        let inkBlocks: [InkBlock] = editor.blocks.compactMap { block in
            if case .ink(let value) = block { return value }
            return nil
        }
        XCTAssertEqual(inkBlocks.count, 1)
        XCTAssertEqual(inkBlocks.first?.id, ink.id)
        XCTAssertEqual(inkBlocks.first?.drawingData, Data([0x01, 0x02, 0x03, 0x04]))
    }
}
