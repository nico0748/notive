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
        saveState = .idle
    }

    /// Markdown モードとリッチモードを切り替える（F-EDIT-02）。
    public func toggleMarkdownMode() {
        if isMarkdownMode {
            // Markdown → リッチ: テキストを解析してブロックへ反映。
            blocks = converter.blocks(from: markdownText)
            isMarkdownMode = false
        } else {
            // リッチ → Markdown: 現在のブロックをテキスト化。
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
            blocks = converter.blocks(from: markdownText)
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
