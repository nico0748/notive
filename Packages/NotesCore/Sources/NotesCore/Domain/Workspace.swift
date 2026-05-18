import Foundation

/// ワークスペースの種別（F-ORG-01）。
public enum WorkspaceKind: String, Codable, Hashable, Sendable {
    case personal
    case team
}

/// 個人またはチームのワークスペースを表すドメインエンティティ。
///
/// 本イテレーションでは個人ワークスペースのローカル作成のみを実装し、
/// チームワークスペースはスタブ（型としてのみ存在）とする。
public struct Workspace: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: WorkspaceKind
    /// 作成者（オーナー）の `User.id`。
    public var ownerID: UUID
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        kind: WorkspaceKind = .personal,
        ownerID: UUID,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.ownerID = ownerID
        self.createdAt = createdAt
    }

    /// 指定ユーザーの個人ワークスペースを生成する。
    public static func makePersonal(ownerID: UUID) -> Workspace {
        Workspace(name: NotesConstants.Naming.personalWorkspace, kind: .personal, ownerID: ownerID)
    }
}
