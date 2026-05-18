import Foundation
import SwiftData

/// 合成ルート（Composition Root）。
///
/// 永続化層（SwiftData リポジトリ）・ユースケース・ViewModel を組み立てて配線する。
/// アプリターゲットを薄く保つため、依存の結線をこの 1 箇所に集約する。
/// 依存性注入はイニシャライザインジェクションで行い、DI コンテナは用いない。
@MainActor
public enum AppComposition {

    /// 指定した `ModelContext` から `AppViewModel` を構築する。
    public static func makeAppViewModel(modelContext: ModelContext) -> AppViewModel {
        let userRepository = SwiftDataUserRepository(context: modelContext)
        let workspaceRepository = SwiftDataWorkspaceRepository(context: modelContext)
        let folderRepository = SwiftDataFolderRepository(context: modelContext)
        let noteRepository = SwiftDataNoteRepository(context: modelContext)

        let noteService = NoteService(repository: noteRepository)
        let folderService = FolderService(folderRepository: folderRepository, noteRepository: noteRepository)
        let searchService = SearchService(repository: noteRepository)
        let workspaceService = WorkspaceService(
            userRepository: userRepository,
            workspaceRepository: workspaceRepository
        )

        return AppViewModel(
            noteService: noteService,
            folderService: folderService,
            searchService: searchService,
            workspaceService: workspaceService
        )
    }
}
