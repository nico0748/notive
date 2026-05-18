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
        colorHex: String = Tag.defaultColorHex,
        workspaceID: UUID
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.workspaceID = workspaceID
    }

    /// 既定のタグ色。
    public static let defaultColorHex = "#3478F6"

    /// 新規タグ作成時に循環利用する配色パレット。
    public static let palette: [String] = [
        "#3478F6", "#34C759", "#FF9500", "#FF3B30",
        "#AF52DE", "#FF2D55", "#5AC8FA", "#FFCC00"
    ]

    /// 既存タグ数に応じてパレットから次の色を選ぶ。
    public static func paletteColor(forIndex index: Int) -> String {
        guard !palette.isEmpty else { return defaultColorHex }
        return palette[index % palette.count]
    }
}
