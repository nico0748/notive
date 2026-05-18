import Foundation

/// ノートを整理するフォルダ（F-ORG-02）。`parentID` により無制限の階層を表現する。
public struct Folder: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var workspaceID: UUID
    /// 親フォルダの識別子。ルート直下の場合は `nil`。
    public var parentID: UUID?
    public var createdAt: Date
    /// 同一階層内での手動並び順。
    public var sortIndex: Int

    public init(
        id: UUID = UUID(),
        name: String,
        workspaceID: UUID,
        parentID: UUID? = nil,
        createdAt: Date = .now,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.workspaceID = workspaceID
        self.parentID = parentID
        self.createdAt = createdAt
        self.sortIndex = sortIndex
    }
}
