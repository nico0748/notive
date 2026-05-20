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
    func testUpdateInkBlockReplacesLayersAndTemplate() async throws {
        let (editor, repository) = makeEditor()
        let note = Note(title: "手書き", workspaceID: UUID())
        try await repository.save(note)
        await editor.open(note)

        let inkID = editor.addInkBlock()
        var ink = try XCTUnwrap(editor.inkBlock(id: inkID))
        ink.drawingData = Data([0x0A])
        ink.backgroundData = Data([0x0B, 0x0C])
        ink.template = .grid
        editor.updateInkBlock(ink)

        let result = try XCTUnwrap(editor.inkBlock(id: inkID))
        XCTAssertEqual(result.drawingData, Data([0x0A]))
        XCTAssertEqual(result.backgroundData, Data([0x0B, 0x0C]))
        XCTAssertEqual(result.template, .grid)
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

    @MainActor
    func testAppendPdfBlockAndRetrieve() async throws {
        let (editor, repository) = makeEditor()
        let note = Note(title: "PDF", workspaceID: UUID())
        try await repository.save(note)
        await editor.open(note)

        let pdf = PdfBlock(documentData: Data([0x25, 0x50]), caption: "資料", pageCount: 1)
        editor.appendPdfBlock(pdf)
        XCTAssertEqual(editor.pdfBlock(id: pdf.id)?.caption, "資料")
        XCTAssertEqual(editor.pdfBlock(id: pdf.id)?.pageCount, 1)
    }

    @MainActor
    func testPdfBlockSurvivesMarkdownRoundTrip() async throws {
        let (editor, repository) = makeEditor()
        let note = Note(title: "PDF", workspaceID: UUID())
        try await repository.save(note)
        await editor.open(note)

        let pdf = PdfBlock(documentData: Data([0x25, 0x50, 0x44, 0x46]), caption: "資料", pageCount: 2)
        editor.appendPdfBlock(pdf)

        editor.toggleMarkdownMode()
        XCTAssertTrue(editor.markdownText.contains("notive-pdf:\(pdf.id.uuidString)"))

        editor.toggleMarkdownMode()
        let pdfBlocks: [PdfBlock] = editor.blocks.compactMap { block in
            if case .pdf(let value) = block { return value }
            return nil
        }
        XCTAssertEqual(pdfBlocks.count, 1)
        XCTAssertEqual(pdfBlocks.first?.documentData, Data([0x25, 0x50, 0x44, 0x46]))
        XCTAssertEqual(pdfBlocks.first?.caption, "資料")
    }
}
