import Foundation

/// ノートのバージョン履歴スナップショット（F-EDIT-08）。
///
/// 編集ごとにノートの状態（タイトル・ブロック・タグ）をスナップショットとして保持し、
/// 直近30日分の履歴から復元できるようにする。スナップショットは不変（イミュータブル）
/// であり、生成後に書き換わることはない。
public struct NoteVersion: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// このバージョンが属するノートの識別子。
    public var noteID: UUID
    /// スナップショットを記録した時刻。
    public var capturedAt: Date
    public var title: String
    public var blocks: [Block]
    public var tagIDs: [UUID]

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        capturedAt: Date = .now,
        title: String,
        blocks: [Block],
        tagIDs: [UUID] = []
    ) {
        self.id = id
        self.noteID = noteID
        self.capturedAt = capturedAt
        self.title = title
        self.blocks = blocks
        self.tagIDs = tagIDs
    }

    /// 与えられたノートと内容（title / blocks / tagIDs）が一致するか。
    /// 履歴の冗長な重複を避けるための比較に用いる。
    public func hasSameContent(as note: Note) -> Bool {
        title == note.title && blocks == note.blocks && tagIDs == note.tagIDs
    }
}
