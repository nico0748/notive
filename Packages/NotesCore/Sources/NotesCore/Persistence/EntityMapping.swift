import Foundation

/// ドメイン値型 ⇄ SwiftData エンティティの相互変換を担う。
///
/// ブロック配列とタグ識別子配列は JSON データとしてエンティティに格納するため、
/// その符号化／復号もここで一元管理する。
enum EntityMapping {

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // MARK: - 符号化ヘルパ

    static func encodeBlocks(_ blocks: [Block]) throws -> Data {
        do {
            return try encoder.encode(blocks)
        } catch {
            throw RepositoryError.storageFailure("ブロックの符号化に失敗: \(error.localizedDescription)")
        }
    }

    static func decodeBlocks(_ data: Data) throws -> [Block] {
        guard !data.isEmpty else { return [] }
        do {
            return try decoder.decode([Block].self, from: data)
        } catch {
            throw RepositoryError.storageFailure("ブロックの復号に失敗: \(error.localizedDescription)")
        }
    }

    static func encodeIDs(_ ids: [UUID]) throws -> Data {
        do {
            return try encoder.encode(ids)
        } catch {
            throw RepositoryError.storageFailure("識別子配列の符号化に失敗: \(error.localizedDescription)")
        }
    }

    static func decodeIDs(_ data: Data) throws -> [UUID] {
        guard !data.isEmpty else { return [] }
        do {
            return try decoder.decode([UUID].self, from: data)
        } catch {
            throw RepositoryError.storageFailure("識別子配列の復号に失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - User

    static func makeDomain(_ entity: UserEntity) -> User {
        User(
            id: entity.id,
            displayName: entity.displayName,
            email: entity.email,
            isLocal: entity.isLocal,
            createdAt: entity.createdAt
        )
    }

    static func makeEntity(_ user: User) -> UserEntity {
        UserEntity(
            id: user.id,
            displayName: user.displayName,
            email: user.email,
            isLocal: user.isLocal,
            createdAt: user.createdAt
        )
    }

    static func apply(_ user: User, to entity: UserEntity) {
        entity.displayName = user.displayName
        entity.email = user.email
        entity.isLocal = user.isLocal
        entity.createdAt = user.createdAt
    }

    // MARK: - Workspace

    static func makeDomain(_ entity: WorkspaceEntity) -> Workspace {
        Workspace(
            id: entity.id,
            name: entity.name,
            kind: WorkspaceKind(rawValue: entity.kindRaw) ?? .personal,
            ownerID: entity.ownerID,
            createdAt: entity.createdAt
        )
    }

    static func makeEntity(_ workspace: Workspace) -> WorkspaceEntity {
        WorkspaceEntity(
            id: workspace.id,
            name: workspace.name,
            kindRaw: workspace.kind.rawValue,
            ownerID: workspace.ownerID,
            createdAt: workspace.createdAt
        )
    }

    static func apply(_ workspace: Workspace, to entity: WorkspaceEntity) {
        entity.name = workspace.name
        entity.kindRaw = workspace.kind.rawValue
        entity.ownerID = workspace.ownerID
        entity.createdAt = workspace.createdAt
    }

    // MARK: - Folder

    static func makeDomain(_ entity: FolderEntity) -> Folder {
        Folder(
            id: entity.id,
            name: entity.name,
            workspaceID: entity.workspaceID,
            parentID: entity.parentID,
            createdAt: entity.createdAt,
            sortIndex: entity.sortIndex
        )
    }

    static func makeEntity(_ folder: Folder) -> FolderEntity {
        FolderEntity(
            id: folder.id,
            name: folder.name,
            workspaceID: folder.workspaceID,
            parentID: folder.parentID,
            createdAt: folder.createdAt,
            sortIndex: folder.sortIndex
        )
    }

    static func apply(_ folder: Folder, to entity: FolderEntity) {
        entity.name = folder.name
        entity.workspaceID = folder.workspaceID
        entity.parentID = folder.parentID
        entity.createdAt = folder.createdAt
        entity.sortIndex = folder.sortIndex
    }

    // MARK: - Note

    static func makeDomain(_ entity: NoteEntity) throws -> Note {
        Note(
            id: entity.id,
            title: entity.title,
            blocks: try decodeBlocks(entity.bodyData),
            workspaceID: entity.workspaceID,
            folderID: entity.folderID,
            tagIDs: try decodeIDs(entity.tagIDsData),
            isPinned: entity.isPinned,
            isFavorite: entity.isFavorite,
            isTrashed: entity.isTrashed,
            trashedAt: entity.trashedAt,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            sortIndex: entity.sortIndex
        )
    }

    static func makeEntity(_ note: Note) throws -> NoteEntity {
        NoteEntity(
            id: note.id,
            title: note.title,
            bodyData: try encodeBlocks(note.blocks),
            tagIDsData: try encodeIDs(note.tagIDs),
            workspaceID: note.workspaceID,
            folderID: note.folderID,
            isPinned: note.isPinned,
            isFavorite: note.isFavorite,
            isTrashed: note.isTrashed,
            trashedAt: note.trashedAt,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            sortIndex: note.sortIndex
        )
    }

    static func apply(_ note: Note, to entity: NoteEntity) throws {
        entity.title = note.title
        entity.bodyData = try encodeBlocks(note.blocks)
        entity.tagIDsData = try encodeIDs(note.tagIDs)
        entity.workspaceID = note.workspaceID
        entity.folderID = note.folderID
        entity.isPinned = note.isPinned
        entity.isFavorite = note.isFavorite
        entity.isTrashed = note.isTrashed
        entity.trashedAt = note.trashedAt
        entity.createdAt = note.createdAt
        entity.updatedAt = note.updatedAt
        entity.sortIndex = note.sortIndex
    }

    // MARK: - NoteVersion

    static func makeDomain(_ entity: NoteVersionEntity) throws -> NoteVersion {
        NoteVersion(
            id: entity.id,
            noteID: entity.noteID,
            capturedAt: entity.capturedAt,
            title: entity.title,
            blocks: try decodeBlocks(entity.bodyData),
            tagIDs: try decodeIDs(entity.tagIDsData)
        )
    }

    static func makeEntity(_ version: NoteVersion) throws -> NoteVersionEntity {
        NoteVersionEntity(
            id: version.id,
            noteID: version.noteID,
            capturedAt: version.capturedAt,
            title: version.title,
            bodyData: try encodeBlocks(version.blocks),
            tagIDsData: try encodeIDs(version.tagIDs)
        )
    }

    // MARK: - Tag

    static func makeDomain(_ entity: TagEntity) -> Tag {
        Tag(
            id: entity.id,
            name: entity.name,
            colorHex: entity.colorHex,
            workspaceID: entity.workspaceID
        )
    }

    static func makeEntity(_ tag: Tag) -> TagEntity {
        TagEntity(
            id: tag.id,
            name: tag.name,
            colorHex: tag.colorHex,
            workspaceID: tag.workspaceID
        )
    }

    static func apply(_ tag: Tag, to entity: TagEntity) {
        entity.name = tag.name
        entity.colorHex = tag.colorHex
        entity.workspaceID = tag.workspaceID
    }
}
