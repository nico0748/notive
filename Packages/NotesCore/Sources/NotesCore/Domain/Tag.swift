import Foundation

/// ノートに付与するタグ（F-ORG-03）。
public struct Tag: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    /// 表示色。`#RRGGBB` 形式の文字列で保持する。
    public var colorHex: String
    public var workspaceID: UUID

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#3478F6",
        workspaceID: UUID
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.workspaceID = workspaceID
    }
}
