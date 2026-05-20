import Foundation
import SwiftData

/// SwiftData の `ModelContainer` を生成するファクトリ。
///
/// アプリ（合成ルート）とテストの双方から利用する。`inMemory: true` を指定すると
/// ディスクに書き込まないインメモリストアを生成するため、ユニットテストに適する。
public enum ModelContainerFactory {

    /// 永続化対象の全 `@Model` 型。
    static var modelTypes: [any PersistentModel.Type] {
        [
            UserEntity.self,
            WorkspaceEntity.self,
            FolderEntity.self,
            NoteEntity.self,
            TagEntity.self,
            NoteVersionEntity.self
        ]
    }

    /// `ModelContainer` を生成する。
    /// - Parameter inMemory: `true` の場合はインメモリストアを使用する。
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(modelTypes)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            throw RepositoryError.storageFailure("ModelContainer の生成に失敗: \(error.localizedDescription)")
        }
    }
}
