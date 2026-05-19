import Foundation
import Observation

/// ノートエディタの状態管理と自動保存（F-EDIT-07）を担う ViewModel。
@MainActor
@Observable
public final class EditorViewModel {

    /// 保存状態。ステータス表示に用いる。
    public enum SaveState: Equatable {
        case idle
        case editing
        case saving
        case saved
        case failed(String)

        public var label: String {
            switch self {
            case .idle: return ""
            case .editing: return "編集中…"
            case .saving: return "保存中…"
            case .saved: return "保存済み"
            case .failed(let message): return "保存失敗: \(message)"
            }
        }
    }

    public private(set) var note: Note?
    public var title: String = ""
    public var blocks: [Block] = []
    /// Markdown 入力モード（F-EDIT-02）で編集中のテキスト。
    public var markdownText: String = ""
    public private(set) var isMarkdownMode: Bool = false
    public private(set) var saveState: SaveState = .idle

    /// 編集中ノートに付与されているタグの識別子（F-ORG-03）。
    public private(set) var tagIDs: [UUID] = []
    /// 現在のワークスペースで選択可能なタグ一覧。
    public private(set) var availableTags: [Tag] = []

    private let noteService: NoteService
    private let tagService: TagService
    private let converter = MarkdownConverter()
    private var autosaveTask: Task<Void, Never>?
    /// 手書きブロックの実データ。Markdown はストロークを表現できないため、
    /// Markdown 往復変換でも手書きを失わないよう識別子で保持する。
    private var inkBlocksByID: [UUID: InkBlock] = [:]

    public init(noteService: NoteService, tagService: TagService) {
        self.noteService = noteService
        self.tagService = tagService
    }

    /// 編集対象のノートに付与されたタグを、ワークスペース内での表示順で返す。
    public var assignedTags: [Tag] {
        tagIDs.compactMap { id in availableTags.first { $0.id == id } }
    }

    /// まだ付与されていない、選択可能なタグ。
    public var unassignedTags: [Tag] {
        availableTags.filter { !tagIDs.contains($0.id) }
    }

    /// 編集対象のノートを読み込む。別ノートを開く前に保留中の保存をフラッシュする。
    public func open(_ note: Note) async {
        await flushPendingSave()
        self.note = note
        title = note.title
        blocks = note.blocks
        tagIDs = note.tagIDs
        isMarkdownMode = false
        markdownText = ""
        saveState = .saved
        inkBlocksByID = [:]
        captureInkBlocks()
        availableTags = (try? await tagService.tags(in: note.workspaceID)) ?? []
    }

    /// 編集対象を閉じる。保留中の保存を確定する。
    public func close() async {
        await flushPendingSave()
        note = nil
        title = ""
        blocks = []
        markdownText = ""
        tagIDs = []
        availableTags = []
        inkBlocksByID = [:]
        saveState = .idle
    }

    /// Markdown モードとリッチモードを切り替える（F-EDIT-02）。
    public func toggleMarkdownMode() {
        if isMarkdownMode {
            // Markdown → リッチ: テキストを解析し、手書きの実データを復元する。
            blocks = restoreInkBlocks(in: converter.blocks(from: markdownText))
            isMarkdownMode = false
        } else {
            // リッチ → Markdown: 手書きの実データを退避してからテキスト化する。
            captureInkBlocks()
            markdownText = converter.markdown(from: blocks)
            isMarkdownMode = true
        }
        scheduleAutosave()
    }

    /// 編集が発生したら呼び出す。デバウンス後に自動保存する（F-EDIT-07）。
    public func scheduleAutosave() {
        guard note != nil else { return }
        saveState = .editing
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: NotesConstants.Autosave.debounce)
            guard !Task.isCancelled else { return }
            await self?.saveNow()
        }
    }

    /// ただちに保存する。
    public func saveNow() async {
        guard var current = note else { return }
        autosaveTask?.cancel()
        saveState = .saving

        if isMarkdownMode {
            blocks = restoreInkBlocks(in: converter.blocks(from: markdownText))
        }
        current.title = title
        current.blocks = blocks
        current.tagIDs = tagIDs

        do {
            let saved = try await noteService.save(current)
            note = saved
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    /// 保留中の自動保存があれば完了させる。
    private func flushPendingSave() async {
        guard autosaveTask != nil, saveState == .editing else { return }
        await saveNow()
    }

    // MARK: - タグ操作（F-ORG-03）

    /// タグの付与／解除を切り替える。
    public func toggleTag(_ tagID: UUID) {
        guard note != nil else { return }
        if let index = tagIDs.firstIndex(of: tagID) {
            tagIDs.remove(at: index)
        } else {
            tagIDs.append(tagID)
        }
        scheduleAutosave()
    }

    /// 新しいタグを作成し、編集中のノートへ付与する。
    public func createAndAssignTag(named name: String) async {
        guard let note else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let color = Tag.paletteColor(forIndex: availableTags.count)
            let tag = try await tagService.createTag(name: trimmed, colorHex: color, in: note.workspaceID)
            availableTags.append(tag)
            tagIDs.append(tag.id)
            scheduleAutosave()
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    // MARK: - 手書き操作（F-INK-13）

    /// 空の手書きブロックを末尾に追加し、その識別子を返す。
    @discardableResult
    public func addInkBlock() -> UUID {
        let ink = InkBlock()
        blocks.append(.ink(ink))
        scheduleAutosave()
        return ink.id
    }

    /// 指定した手書きブロックの描画データを更新する。
    public func updateInkBlock(id: UUID, drawingData: Data) {
        guard let index = blocks.firstIndex(where: { $0.id == id }),
              case .ink(var ink) = blocks[index] else { return }
        ink.drawingData = drawingData
        blocks[index] = .ink(ink)
        inkBlocksByID[ink.id] = ink
        scheduleAutosave()
    }

    /// 指定した手書きブロックの現在の内容を返す。
    public func inkBlock(id: UUID) -> InkBlock? {
        for block in blocks {
            if case .ink(let ink) = block, ink.id == id { return ink }
        }
        return nil
    }

    /// 現在のブロック列から手書きの実データを退避する。
    private func captureInkBlocks() {
        for block in blocks {
            if case .ink(let ink) = block, !ink.isEmpty {
                inkBlocksByID[ink.id] = ink
            }
        }
    }

    /// Markdown 解析で生じた空の手書きプレースホルダを、退避済みの実データで復元する。
    private func restoreInkBlocks(in parsed: [Block]) -> [Block] {
        parsed.map { block in
            if case .ink(let ink) = block, ink.isEmpty, let stored = inkBlocksByID[ink.id] {
                return .ink(stored)
            }
            return block
        }
    }

    // MARK: - ブロック操作

    /// 末尾にブロックを追加する。
    public func appendBlock(_ block: Block) {
        blocks.append(block)
        scheduleAutosave()
    }

    /// 指定ブロックの直後に新しいブロックを挿入する。
    public func insertBlock(_ block: Block, after id: UUID) {
        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks.insert(block, at: index + 1)
        } else {
            blocks.append(block)
        }
        scheduleAutosave()
    }

    /// 指定ブロックを削除する。最後の 1 ブロックは削除せず空段落に置き換える。
    public func removeBlock(id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks.remove(at: index)
        if blocks.isEmpty {
            blocks = [.paragraph(ParagraphBlock())]
        }
        scheduleAutosave()
    }

    /// 指定ブロックを更新後の内容で置き換える。
    public func updateBlock(_ block: Block) {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }) else { return }
        blocks[index] = block
        scheduleAutosave()
    }
}
