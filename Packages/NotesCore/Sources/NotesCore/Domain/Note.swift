import Foundation

/// ノートのドメインエンティティ。本文はブロック配列（`blocks`）で表現する。
public struct Note: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    /// ノート本文を構成するブロック列。
    public var blocks: [Block]
    public var workspaceID: UUID
    /// 所属フォルダ。未分類（ルート）の場合は `nil`。
    public var folderID: UUID?
    public var tagIDs: [UUID]
    public var isPinned: Bool
    public var isFavorite: Bool
    /// ゴミ箱（F-ORG-05）に入っているかどうか。
    public var isTrashed: Bool
    /// ゴミ箱へ移動した日時。復元・自動削除判定に用いる。
    public var trashedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    /// 手動並び替え用のインデックス。
    public var sortIndex: Int

    public init(
        id: UUID = UUID(),
        title: String = NotesConstants.Naming.untitledNote,
        blocks: [Block] = [.paragraph(ParagraphBlock())],
        workspaceID: UUID,
        folderID: UUID? = nil,
        tagIDs: [UUID] = [],
        isPinned: Bool = false,
        isFavorite: Bool = false,
        isTrashed: Bool = false,
        trashedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.title = title
        self.blocks = blocks
        self.workspaceID = workspaceID
        self.folderID = folderID
        self.tagIDs = tagIDs
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.isTrashed = isTrashed
        self.trashedAt = trashedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortIndex = sortIndex
    }

    /// タイトルと全ブロックを連結した検索用テキスト（F-SEARCH-01）。
    public var searchableText: String {
        ([title] + blocks.map(\.plainText)).joined(separator: "\n")
    }

    /// 指定クエリにタイトルまたは本文が（大文字小文字を無視して）一致するか判定する。
    public func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return searchableText.range(of: trimmed, options: .caseInsensitive) != nil
    }
}

/// ノート一覧の並び替え基準（F-ORG-06）。
public enum NoteSortOrder: String, Codable, CaseIterable, Sendable {
    case updatedDescending
    case createdDescending
    case titleAscending
    case manual

    /// 一覧表示用の日本語ラベル。
    public var label: String {
        switch self {
        case .updatedDescending: return "更新日"
        case .createdDescending: return "作成日"
        case .titleAscending: return "タイトル"
        case .manual: return "手動"
        }
    }
}

extension Array where Element == Note {
    /// 指定した並び順でソートした新しい配列を返す。ピン留めは常に先頭へ寄せる。
    public func sorted(by order: NoteSortOrder) -> [Note] {
        sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            switch order {
            case .updatedDescending: return lhs.updatedAt > rhs.updatedAt
            case .createdDescending: return lhs.createdAt > rhs.createdAt
            case .titleAscending:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .manual: return lhs.sortIndex < rhs.sortIndex
            }
        }
    }
}
