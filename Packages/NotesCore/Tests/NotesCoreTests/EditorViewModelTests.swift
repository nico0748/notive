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
    private func makeEditorWithVersioning() -> (EditorViewModel, FakeNoteRepository, FakeNoteVersionRepository) {
        let noteRepository = FakeNoteRepository()
        let versionRepository = FakeNoteVersionRepository()
        let editor = EditorViewModel(
            noteService: NoteService(repository: noteRepository),
            tagService: TagService(repository: FakeTagRepository()),
            versionService: NoteVersionService(repository: versionRepository)
        )
        return (editor, noteRepository, versionRepository)
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
    func testSaveNowRecordsVersion() async throws {
        let (editor, repository, versionRepository) = makeEditorWithVersioning()
        let note = Note(title: "履歴対象", workspaceID: UUID())
        try await repository.save(note)
        await editor.open(note)

        editor.title = "履歴対象（編集）"
        await editor.saveNow()

        XCTAssertEqual(versionRepository.storage.count, 1)
        let saved = versionRepository.storage.values.first
        XCTAssertEqual(saved?.title, "履歴対象（編集）")
        XCTAssertEqual(saved?.noteID, note.id)
    }

    @MainActor
    func testRestoreAppliesVersionContent() async throws {
        let (editor, repository, versionRepository) = makeEditorWithVersioning()
        let note = Note(title: "初期", workspaceID: UUID())
        try await repository.save(note)
        await editor.open(note)

        // 履歴 1（過去の状態）。
        let snapshot = NoteVersion(
            noteID: note.id,
            capturedAt: .now.addingTimeInterval(-120),
            title: "過去のタイトル",
            blocks: [.paragraph(ParagraphBlock(text: "過去本文"))]
        )
        try await versionRepository.save(snapshot)

        // 現在の編集状態を別の内容に変える。
        editor.title = "現在のタイトル"
        editor.blocks = [.paragraph(ParagraphBlock(text: "現在本文"))]
        await editor.saveNow()

        await editor.restore(version: snapshot)

        XCTAssertEqual(editor.title, "過去のタイトル")
        XCTAssertEqual(editor.blocks.count, 1)
        let saved = try await repository.note(id: note.id)
        XCTAssertEqual(saved?.title, "過去のタイトル")
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
