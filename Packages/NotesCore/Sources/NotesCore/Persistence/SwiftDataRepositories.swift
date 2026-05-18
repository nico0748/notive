import Foundation
import SwiftData

// MARK: - SwiftData リポジトリ実装
//
// `ModelContext` は `Sendable` ではないため、各リポジトリは `@MainActor` に隔離する。
// メソッドは `async` 宣言とし、将来バックグラウンドコンテキストへ移行する余地を残す。

/// `UserRepository` の SwiftData 実装。
@MainActor
public final class SwiftDataUserRepository: UserRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func currentUser() async throws -> User? {
        var descriptor = FetchDescriptor<UserEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        let entities = try fetch(descriptor)
        return entities.first.map(EntityMapping.makeDomain)
    }

    public func save(_ user: User) async throws {
        let id = user.id
        let existing = try fetch(FetchDescriptor<UserEntity>(predicate: #Predicate { $0.id == id })).first
        if let existing {
            EntityMapping.apply(user, to: existing)
        } else {
            context.insert(EntityMapping.makeEntity(user))
        }
        try persist()
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do { return try context.fetch(descriptor) } catch {
            throw RepositoryError.storageFailure(error.localizedDescription)
        }
    }

    private func persist() throws {
        do { try context.save() } catch {
            throw RepositoryError.storageFailure(error.localizedDescription)
        }
    }
}

/// `WorkspaceRepository` の SwiftData 実装。
@MainActor
public final class SwiftDataWorkspaceRepository: WorkspaceRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func allWorkspaces() async throws -> [Workspace] {
        let descriptor = FetchDescriptor<WorkspaceEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try fetch(descriptor).map(EntityMapping.makeDomain)
    }

    public func save(_ workspace: Workspace) async throws {
        let id = workspace.id
        let existing = try fetch(FetchDescriptor<WorkspaceEntity>(predicate: #Predicate { $0.id == id })).first
        if let existing {
            EntityMapping.apply(workspace, to: existing)
        } else {
            context.insert(EntityMapping.makeEntity(workspace))
        }
        try persist()
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do { return try context.fetch(descriptor) } catch {
            throw RepositoryError.storageFailure(error.localizedDescription)
        }
    }

    private func persist() throws {
        do { try context.save() } catch {
            throw RepositoryError.storageFailure(error.localizedDescription)
        }
    }
}

/// `FolderRepository` の SwiftData 実装。
@MainActor
public final class SwiftDataFolderRepository: FolderRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func folders(workspaceID: UUID) async throws -> [Folder] {
        let descriptor = FetchDescriptor<FolderEntity>(
            predicate: #Predicate { $0.workspaceID == workspaceID },
            sortBy: [SortDescriptor(\.sortIndex, order: .forward)]
        )
        return try fetch(descriptor).map(EntityMapping.makeDomain)
    }

    public func save(_ folder: Folder) async throws {
        let id = folder.id
        let existing = try fetch(FetchDescriptor<FolderEntity>(predicate: #Predicate { $0.id == id })).first
        if let existing {
            EntityMapping.apply(folder, to: existing)
        } else {
            context.insert(EntityMapping.makeEntity(folder))
        }
        try persist()
    }

    public func delete(id: UUID) async throws {
        guard let entity = try fetch(FetchDescriptor<FolderEntity>(predicate: #Predicate { $0.id == id })).first else {
            throw RepositoryError.notFound(id: id)
        }
        context.delete(entity)
        try persist()
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do { return try context.fetch(descriptor) } catch {
            throw RepositoryError.storageFailure(error.localizedDescription)
        }
    }

    private func persist() throws {
        do { try context.save() } catch {
            throw RepositoryError.storageFailure(error.localizedDescription)
        }
    }
}

/// `NoteRepository` の SwiftData 実装。
@MainActor
public final class SwiftDataNoteRepository: NoteRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func allNotes(workspaceID: UUID) async throws -> [Note] {
        let descriptor = FetchDescriptor<NoteEntity>(
            predicate: #Predicate { $0.workspaceID == workspaceID },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try fetch(descriptor).map { try EntityMapping.makeDomain($0) }
    }

    public func note(id: UUID) async throws -> Note? {
        let entity = try fetch(FetchDescriptor<NoteEntity>(predicate: #Predicate { $0.id == id })).first
        return try entity.map { try EntityMapping.makeDomain($0) }
    }

    public func save(_ note: Note) async throws {
        let id = note.id
        let existing = try fetch(FetchDescriptor<NoteEntity>(predicate: #Predicate { $0.id == id })).first
        if let existing {
            try EntityMapping.apply(note, to: existing)
        } else {
            context.insert(try EntityMapping.makeEntity(note))
        }
        try persist()
    }

    public func delete(id: UUID) async throws {
        guard let entity = try fetch(FetchDescriptor<NoteEntity>(predicate: #Predicate { $0.id == id })).first else {
            throw RepositoryError.notFound(id: id)
        }
        context.delete(entity)
        try persist()
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do { return try context.fetch(descriptor) } catch {
            throw RepositoryError.storageFailure(error.localizedDescription)
        }
    }

    private func persist() throws {
        do { try context.save() } catch {
            throw RepositoryError.storageFailure(error.localizedDescription)
        }
    }
}

/// `TagRepository` の SwiftData 実装。
@MainActor
public final class SwiftDataTagRepository: TagRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func tags(workspaceID: UUID) async throws -> [Tag] {
        let descriptor = FetchDescriptor<TagEntity>(
            predicate: #Predicate { $0.workspaceID == workspaceID },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try fetch(descriptor).map(EntityMapping.makeDomain)
    }

    public func save(_ tag: Tag) async throws {
        let id = tag.id
        let existing = try fetch(FetchDescriptor<TagEntity>(predicate: #Predicate { $0.id == id })).first
        if let existing {
            EntityMapping.apply(tag, to: existing)
        } else {
            context.insert(EntityMapping.makeEntity(tag))
        }
        try persist()
    }

    public func delete(id: UUID) async throws {
        guard let entity = try fetch(FetchDescriptor<TagEntity>(predicate: #Predicate { $0.id == id })).first else {
            throw RepositoryError.notFound(id: id)
        }
        context.delete(entity)
        try persist()
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do { return try context.fetch(descriptor) } catch {
            throw RepositoryError.storageFailure(error.localizedDescription)
        }
    }

    private func persist() throws {
        do { try context.save() } catch {
            throw RepositoryError.storageFailure(error.localizedDescription)
        }
    }
}
