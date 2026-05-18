import Foundation

/// タグの CRUD を担うユースケース（F-ORG-03）。
public final class TagService {
    private let repository: TagRepository

    public init(repository: TagRepository) {
        self.repository = repository
    }

    /// 指定ワークスペースの全タグを返す。
    public func tags(in workspaceID: UUID) async throws -> [Tag] {
        try await repository.tags(workspaceID: workspaceID)
    }

    /// タグを新規作成して永続化する。
    public func createTag(
        name: String,
        colorHex: String = Tag.defaultColorHex,
        in workspaceID: UUID
    ) async throws -> Tag {
        let tag = Tag(name: name, colorHex: colorHex, workspaceID: workspaceID)
        try await repository.save(tag)
        return tag
    }

    /// タグ名・色を更新する。
    @discardableResult
    public func update(_ tag: Tag) async throws -> Tag {
        try await repository.save(tag)
        return tag
    }

    /// タグを削除する。
    public func delete(_ tag: Tag) async throws {
        try await repository.delete(id: tag.id)
    }
}
