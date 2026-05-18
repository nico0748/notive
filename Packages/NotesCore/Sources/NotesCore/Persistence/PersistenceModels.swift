import Foundation
import SwiftData

// MARK: - SwiftData 永続化モデル
//
// ドメイン層（`Note` 等の値型）とは別に、SwiftData の `@Model` クラスを
// 永続化専用の表現として定義する。リレーションシップは扱わず、
// `UUID` による参照（`workspaceID` / `parentID` など）で関連を表現する。
// これによりカスケード挙動を明示的にサービス層で制御でき、
// 将来ストアを差し替える際の影響範囲も限定できる。

@Model
final class UserEntity {
    var id: UUID
    var displayName: String
    var email: String?
    var isLocal: Bool
    var createdAt: Date

    init(id: UUID, displayName: String, email: String?, isLocal: Bool, createdAt: Date) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.isLocal = isLocal
        self.createdAt = createdAt
    }
}

@Model
final class WorkspaceEntity {
    var id: UUID
    var name: String
    var kindRaw: String
    var ownerID: UUID
    var createdAt: Date

    init(id: UUID, name: String, kindRaw: String, ownerID: UUID, createdAt: Date) {
        self.id = id
        self.name = name
        self.kindRaw = kindRaw
        self.ownerID = ownerID
        self.createdAt = createdAt
    }
}

@Model
final class FolderEntity {
    var id: UUID
    var name: String
    var workspaceID: UUID
    var parentID: UUID?
    var createdAt: Date
    var sortIndex: Int

    init(id: UUID, name: String, workspaceID: UUID, parentID: UUID?, createdAt: Date, sortIndex: Int) {
        self.id = id
        self.name = name
        self.workspaceID = workspaceID
        self.parentID = parentID
        self.createdAt = createdAt
        self.sortIndex = sortIndex
    }
}

@Model
final class NoteEntity {
    var id: UUID
    var title: String
    /// `[Block]` を JSON エンコードしたデータ。
    var bodyData: Data
    /// `[UUID]`（タグ識別子）を JSON エンコードしたデータ。
    var tagIDsData: Data
    var workspaceID: UUID
    var folderID: UUID?
    var isPinned: Bool
    var isFavorite: Bool
    var isTrashed: Bool
    var trashedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var sortIndex: Int

    init(
        id: UUID,
        title: String,
        bodyData: Data,
        tagIDsData: Data,
        workspaceID: UUID,
        folderID: UUID?,
        isPinned: Bool,
        isFavorite: Bool,
        isTrashed: Bool,
        trashedAt: Date?,
        createdAt: Date,
        updatedAt: Date,
        sortIndex: Int
    ) {
        self.id = id
        self.title = title
        self.bodyData = bodyData
        self.tagIDsData = tagIDsData
        self.workspaceID = workspaceID
        self.folderID = folderID
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.isTrashed = isTrashed
        self.trashedAt = trashedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortIndex = sortIndex
    }
}

@Model
final class TagEntity {
    var id: UUID
    var name: String
    var colorHex: String
    var workspaceID: UUID

    init(id: UUID, name: String, colorHex: String, workspaceID: UUID) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.workspaceID = workspaceID
    }
}
