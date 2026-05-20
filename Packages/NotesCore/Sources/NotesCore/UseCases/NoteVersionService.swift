import Foundation

/// ノートのバージョン履歴（F-EDIT-08）を管理するユースケース。
///
/// 編集ごとにスナップショットを保持し、直近 `NotesConstants.VersionHistory.retentionDays`
/// 日分の履歴から復元できる。短時間に連続する保存は内容が変化しても直前のスナップショットを
/// 置き換える（ストレージ消費の抑制）。
public final class NoteVersionService {
    private let repository: NoteVersionRepository

    public init(repository: NoteVersionRepository) {
        self.repository = repository
    }

    /// 指定ノートのバージョン一覧を新しい順で返す。
    public func versions(of noteID: UUID) async throws -> [NoteVersion] {
        try await repository.versions(noteID: noteID)
    }

    /// 指定 ID のバージョンを取り出す。
    public func version(_ versionID: UUID, of noteID: UUID) async throws -> NoteVersion? {
        try await repository.versions(noteID: noteID).first { $0.id == versionID }
    }

    /// ノートの現在の内容をバージョン履歴へ記録する。
    ///
    /// - 直近バージョンと内容が同等であれば何も記録しない（重複防止）。
    /// - 直近バージョンとの間隔が `throttle` 秒未満かつ内容に差異がある場合は、
    ///   直近バージョンを上書きする（短時間に連続する保存をひとつにまとめる）。
    /// - 戻り値は新たに記録したバージョン（記録しなかった場合は `nil`）。
    @discardableResult
    public func recordVersion(of note: Note, now: Date = .now) async throws -> NoteVersion? {
        let existing = try await repository.versions(noteID: note.id)
        if let latest = existing.first {
            if latest.hasSameContent(as: note) { return nil }
            if now.timeIntervalSince(latest.capturedAt) < NotesConstants.VersionHistory.throttle {
                try await repository.delete(id: latest.id)
            }
        }
        let version = NoteVersion(
            noteID: note.id,
            capturedAt: now,
            title: note.title,
            blocks: note.blocks,
            tagIDs: note.tagIDs
        )
        try await repository.save(version)
        return version
    }

    /// 指定ノートのバージョンをすべて削除する（ノート完全削除時のクリーンアップ用）。
    public func deleteAll(of noteID: UUID) async throws {
        try await repository.deleteAll(noteID: noteID)
    }

    /// 保持期間を過ぎたバージョンを削除する。起動時に呼び出す。
    public func purgeExpired(now: Date = .now) async throws {
        let expiry = TimeInterval(NotesConstants.VersionHistory.retentionDays * 24 * 60 * 60)
        let cutoff = now.addingTimeInterval(-expiry)
        try await repository.purgeExpired(before: cutoff)
    }
}
