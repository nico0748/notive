import Foundation
import Observation

/// 中央ペインのノート一覧（F-ORG-06 / F-SEARCH-01）を担う ViewModel。
@MainActor
@Observable
public final class NoteListViewModel {
    /// 現在の選択・検索条件で読み込まれたノート（ソート前）。
    public private(set) var notes: [Note] = []
    public var sortOrder: NoteSortOrder = .updatedDescending
    /// 検索ボックスの入力文字列。空でなければ検索結果を表示する。
    public var searchText: String = ""
    /// 一覧で選択中のノート識別子。
    public var selectedNoteID: UUID?
    public var errorMessage: String?

    private let noteService: NoteService
    private let searchService: SearchService
    private var workspaceID: UUID?
    private var selection: SidebarSelection = .allNotes

    public init(noteService: NoteService, searchService: SearchService) {
        self.noteService = noteService
        self.searchService = searchService
    }

    /// 並び順を適用した表示用ノート配列。
    public var displayedNotes: [Note] {
        notes.sorted(by: sortOrder)
    }

    /// 検索中かどうか。
    public var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// ワークスペースとサイドバー選択に対応するノートを読み込む。
    public func load(workspaceID: UUID, selection: SidebarSelection) async {
        self.workspaceID = workspaceID
        self.selection = selection
        await reload()
    }

    /// 現在の条件でノート一覧を再取得する。
    public func reload() async {
        guard let workspaceID else { return }
        do {
            if isSearching {
                notes = try await searchService.search(query: searchText, in: workspaceID)
            } else {
                notes = try await fetchNotes(for: selection, workspaceID: workspaceID)
            }
        } catch {
            errorMessage = "ノートの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    private func fetchNotes(for selection: SidebarSelection, workspaceID: UUID) async throws -> [Note] {
        let all = try await noteService.allNotes(in: workspaceID)
        switch selection {
        case .allNotes:
            return all.filter { !$0.isTrashed }
        case .favorites:
            return all.filter { !$0.isTrashed && $0.isFavorite }
        case .trash:
            return all.filter(\.isTrashed)
        case .folder(let folderID):
            return all.filter { !$0.isTrashed && $0.folderID == folderID }
        }
    }

    /// 新規ノートを作成する。フォルダ選択中はそのフォルダ配下に作成する。
    @discardableResult
    public func createNote(workspaceID: UUID) async -> Note? {
        let folderID: UUID? = {
            if case .folder(let id) = selection { return id }
            return nil
        }()
        do {
            let note = try await noteService.createNote(in: workspaceID, folderID: folderID)
            await reload()
            selectedNoteID = note.id
            return note
        } catch {
            errorMessage = "ノートの作成に失敗しました: \(error.localizedDescription)"
            return nil
        }
    }

    /// ノートをゴミ箱へ移動する。
    public func moveToTrash(_ note: Note) async {
        do {
            try await noteService.moveToTrash(note)
            await reload()
        } catch {
            errorMessage = "ゴミ箱への移動に失敗しました: \(error.localizedDescription)"
        }
    }

    /// ゴミ箱からノートを復元する。
    public func restore(_ note: Note) async {
        do {
            try await noteService.restoreFromTrash(note)
            await reload()
        } catch {
            errorMessage = "ノートの復元に失敗しました: \(error.localizedDescription)"
        }
    }

    /// ノートを完全に削除する。
    public func deletePermanently(_ note: Note) async {
        do {
            try await noteService.deletePermanently(note)
            await reload()
        } catch {
            errorMessage = "ノートの削除に失敗しました: \(error.localizedDescription)"
        }
    }

    /// ピン留めの ON/OFF を切り替える。
    public func togglePin(_ note: Note) async {
        var updated = note
        updated.isPinned.toggle()
        await persist(updated, failureMessage: "ピン留めの更新に失敗しました")
    }

    /// お気に入りの ON/OFF を切り替える。
    public func toggleFavorite(_ note: Note) async {
        var updated = note
        updated.isFavorite.toggle()
        await persist(updated, failureMessage: "お気に入りの更新に失敗しました")
    }

    private func persist(_ note: Note, failureMessage: String) async {
        do {
            try await noteService.save(note)
            await reload()
        } catch {
            errorMessage = "\(failureMessage): \(error.localizedDescription)"
        }
    }
}
