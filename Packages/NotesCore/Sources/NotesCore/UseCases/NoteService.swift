import Foundation

/// ノートの CRUD とゴミ箱操作を担うユースケース。
///
/// `NoteRepository` プロトコルにのみ依存し、具体的な永続化技術（SwiftData）には
/// 依存しない。
@MainActor
public final class NoteService {
    private let repository: NoteRepository

    public init(repository: NoteRepository) {
        self.repository = repository
    }

    /// 空のノートを新規作成して永続化する。
    public func createNote(
        in workspaceID: UUID,
        folderID: UUID? = nil,
        title: String = NotesConstants.Naming.untitledNote
    ) async throws -> Note {
        let note = Note(title: title, workspaceID: workspaceID, folderID: folderID)
        try await repository.save(note)
        return note
    }

    /// ノートを保存する。`updatedAt` を現在時刻へ更新する（F-EDIT-07）。
    @discardableResult
    public func save(_ note: Note) async throws -> Note {
        var updated = note
        updated.updatedAt = .now
        try await repository.save(updated)
        return updated
    }

    /// ノートをゴミ箱へ移動する（F-ORG-05）。
    @discardableResult
    public func moveToTrash(_ note: Note) async throws -> Note {
        var updated = note
        updated.isTrashed = true
        updated.trashedAt = .now
        updated.updatedAt = .now
        try await repository.save(updated)
        return updated
    }

    /// ゴミ箱からノートを復元する（F-ORG-05）。
    @discardableResult
    public func restoreFromTrash(_ note: Note) async throws -> Note {
        var updated = note
        updated.isTrashed = false
        updated.trashedAt = nil
        updated.updatedAt = .now
        try await repository.save(updated)
        return updated
    }

    /// ノートをストアから完全に削除する。
    public func deletePermanently(_ note: Note) async throws {
        try await repository.delete(id: note.id)
    }

    /// 指定ワークスペースの全ノート（ゴミ箱含む）を返す。
    public func allNotes(in workspaceID: UUID) async throws -> [Note] {
        try await repository.allNotes(workspaceID: workspaceID)
    }

    /// 指定フォルダ直下の、ゴミ箱に入っていないノートを返す。
    /// - Parameter folderID: `nil` の場合はフォルダ未分類のノートを対象とする。
    public func activeNotes(in workspaceID: UUID, folderID: UUID?) async throws -> [Note] {
        try await repository.allNotes(workspaceID: workspaceID)
            .filter { !$0.isTrashed && $0.folderID == folderID }
    }

    /// ゴミ箱内のノートを返す（F-ORG-05）。
    public func trashedNotes(in workspaceID: UUID) async throws -> [Note] {
        try await repository.allNotes(workspaceID: workspaceID).filter(\.isTrashed)
    }

    /// 保持期間を過ぎたゴミ箱内ノートを完全削除する（F-ORG-05、30日保持）。
    public func purgeExpiredTrash(in workspaceID: UUID, now: Date = .now) async throws {
        let expiry = TimeInterval(NotesConstants.Trash.retentionDays * 24 * 60 * 60)
        let notes = try await repository.allNotes(workspaceID: workspaceID)
        for note in notes where note.isTrashed {
            guard let trashedAt = note.trashedAt else { continue }
            if now.timeIntervalSince(trashedAt) >= expiry {
                try await repository.delete(id: note.id)
            }
        }
    }
}
