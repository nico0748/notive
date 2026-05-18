import Foundation
@testable import NotesCore

// MARK: - テスト用インメモリリポジトリ
//
// SwiftData に依存せずユースケース／ViewModel を検証するための軽量フェイク。

final class FakeUserRepository: UserRepository {
    var storage: [User] = []

    func currentUser() async throws -> User? {
        storage.sorted { $0.createdAt < $1.createdAt }.first
    }

    func save(_ user: User) async throws {
        if let index = storage.firstIndex(where: { $0.id == user.id }) {
            storage[index] = user
        } else {
            storage.append(user)
        }
    }
}

final class FakeWorkspaceRepository: WorkspaceRepository {
    var storage: [Workspace] = []

    func allWorkspaces() async throws -> [Workspace] {
        storage.sorted { $0.createdAt < $1.createdAt }
    }

    func save(_ workspace: Workspace) async throws {
        if let index = storage.firstIndex(where: { $0.id == workspace.id }) {
            storage[index] = workspace
        } else {
            storage.append(workspace)
        }
    }
}

final class FakeFolderRepository: FolderRepository {
    var storage: [UUID: Folder] = [:]

    func folders(workspaceID: UUID) async throws -> [Folder] {
        storage.values
            .filter { $0.workspaceID == workspaceID }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    func save(_ folder: Folder) async throws {
        storage[folder.id] = folder
    }

    func delete(id: UUID) async throws {
        guard storage[id] != nil else { throw RepositoryError.notFound(id: id) }
        storage.removeValue(forKey: id)
    }
}

final class FakeNoteRepository: NoteRepository {
    var storage: [UUID: Note] = [:]

    func allNotes(workspaceID: UUID) async throws -> [Note] {
        storage.values
            .filter { $0.workspaceID == workspaceID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func note(id: UUID) async throws -> Note? {
        storage[id]
    }

    func save(_ note: Note) async throws {
        storage[note.id] = note
    }

    func delete(id: UUID) async throws {
        guard storage[id] != nil else { throw RepositoryError.notFound(id: id) }
        storage.removeValue(forKey: id)
    }
}
