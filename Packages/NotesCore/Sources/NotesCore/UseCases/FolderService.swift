import Foundation

/// フォルダの CRUD と階層操作を担うユースケース（F-ORG-02）。
public final class FolderService {
    private let folderRepository: FolderRepository
    private let noteRepository: NoteRepository

    public init(folderRepository: FolderRepository, noteRepository: NoteRepository) {
        self.folderRepository = folderRepository
        self.noteRepository = noteRepository
    }

    /// 指定ワークスペースの全フォルダを返す。
    public func folders(in workspaceID: UUID) async throws -> [Folder] {
        try await folderRepository.folders(workspaceID: workspaceID)
    }

    /// フォルダを新規作成する。`sortIndex` は同階層の末尾へ採番する。
    public func createFolder(
        in workspaceID: UUID,
        parentID: UUID? = nil,
        name: String = NotesConstants.Naming.untitledFolder
    ) async throws -> Folder {
        let siblings = try await folderRepository.folders(workspaceID: workspaceID)
            .filter { $0.parentID == parentID }
        let nextIndex = (siblings.map(\.sortIndex).max() ?? -1) + 1
        let folder = Folder(name: name, workspaceID: workspaceID, parentID: parentID, sortIndex: nextIndex)
        try await folderRepository.save(folder)
        return folder
    }

    /// フォルダ名を変更する。
    @discardableResult
    public func rename(_ folder: Folder, to name: String) async throws -> Folder {
        var updated = folder
        updated.name = name
        try await folderRepository.save(updated)
        return updated
    }

    /// フォルダを保存する（親変更や並び替えに使用）。
    public func save(_ folder: Folder) async throws {
        try await folderRepository.save(folder)
    }

    /// フォルダを子孫ごと削除する。
    ///
    /// 子孫フォルダはストアから削除し、それらに含まれるノートはゴミ箱へ移動する。
    /// （ノートの即時完全削除を避け、復元の余地を残すための方針）
    public func delete(_ folder: Folder) async throws {
        let allFolders = try await folderRepository.folders(workspaceID: folder.workspaceID)
        let doomedIDs = descendantIDs(of: folder.id, in: allFolders).union([folder.id])

        let notes = try await noteRepository.allNotes(workspaceID: folder.workspaceID)
        for note in notes where note.folderID.map(doomedIDs.contains) == true && !note.isTrashed {
            var trashed = note
            trashed.isTrashed = true
            trashed.trashedAt = .now
            trashed.updatedAt = .now
            try await noteRepository.save(trashed)
        }

        for id in doomedIDs {
            try await folderRepository.delete(id: id)
        }
    }

    /// 指定フォルダの全子孫フォルダ ID を再帰的に収集する。
    private func descendantIDs(of folderID: UUID, in folders: [Folder]) -> Set<UUID> {
        var result: Set<UUID> = []
        let children = folders.filter { $0.parentID == folderID }
        for child in children {
            result.insert(child.id)
            result.formUnion(descendantIDs(of: child.id, in: folders))
        }
        return result
    }
}
