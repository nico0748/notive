import Foundation

/// 永続化層が投げ得るドメインエラー。
public enum RepositoryError: Error, Equatable, Sendable {
    /// 指定した識別子のエンティティが見つからない。
    case notFound(id: UUID)
    /// 永続ストアの操作に失敗した。
    case storageFailure(String)
}

/// ユーザーの永続化を抽象化するリポジトリ（F-AUTH スタブ）。
public protocol UserRepository {
    /// 現在のローカルユーザーを返す。未作成なら `nil`。
    func currentUser() async throws -> User?
    func save(_ user: User) async throws
}

/// ワークスペースの永続化を抽象化するリポジトリ（F-ORG-01）。
public protocol WorkspaceRepository {
    func allWorkspaces() async throws -> [Workspace]
    func save(_ workspace: Workspace) async throws
}

/// フォルダの永続化を抽象化するリポジトリ（F-ORG-02）。
public protocol FolderRepository {
    func folders(workspaceID: UUID) async throws -> [Folder]
    func save(_ folder: Folder) async throws
    func delete(id: UUID) async throws
}

/// ノートの永続化を抽象化するリポジトリ。
///
/// 将来のクラウド同期・共同編集に備え、具体的なストア（SwiftData）に依存しない
/// 抽象としてプロトコル化している。
public protocol NoteRepository {
    /// 指定ワークスペースの全ノート（ゴミ箱を含む）を返す。
    func allNotes(workspaceID: UUID) async throws -> [Note]
    func note(id: UUID) async throws -> Note?
    func save(_ note: Note) async throws
    /// ストアから完全に削除する（ゴミ箱への移動ではない）。
    func delete(id: UUID) async throws
}

/// タグの永続化を抽象化するリポジトリ（F-ORG-03）。
public protocol TagRepository {
    func tags(workspaceID: UUID) async throws -> [Tag]
    func save(_ tag: Tag) async throws
    func delete(id: UUID) async throws
}

/// ノートのバージョン履歴（F-EDIT-08）の永続化を抽象化するリポジトリ。
public protocol NoteVersionRepository {
    /// 指定ノートのバージョンを新しい順に返す。
    func versions(noteID: UUID) async throws -> [NoteVersion]
    /// バージョンを保存する。既存 ID と一致する場合は置き換える。
    func save(_ version: NoteVersion) async throws
    /// 指定識別子のバージョンを削除する。
    func delete(id: UUID) async throws
    /// 指定ノートのすべてのバージョンを削除する。
    func deleteAll(noteID: UUID) async throws
    /// 指定時刻より前に記録されたバージョンをすべて削除する（保持期間超過分の自動削除）。
    func purgeExpired(before cutoff: Date) async throws
}
