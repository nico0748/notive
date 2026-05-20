import Foundation
import Observation

/// アプリ全体の状態（起動フェーズ・現在のユーザー／ワークスペース）と、
/// 各ユースケースへの参照を保持するルート ViewModel。
///
/// macOS 14 / iPadOS 17 以降の Observation フレームワーク（`@Observable`）を用い、
/// Combine には依存しない。
@MainActor
@Observable
public final class AppViewModel {

    /// アプリの起動フェーズ。
    public enum Phase: Equatable {
        /// 永続ストアからの読み込み中。
        case loading
        /// 未サインイン。ログイン（スタブ）画面を表示する。
        case login
        /// サインイン済み。メイン画面を表示する。
        case ready
    }

    public private(set) var phase: Phase = .loading
    public private(set) var currentUser: User?
    public private(set) var currentWorkspace: Workspace?
    /// 直近に発生したエラーの表示用メッセージ。
    public var errorMessage: String?

    public let noteService: NoteService
    public let folderService: FolderService
    public let searchService: SearchService
    public let tagService: TagService
    public let versionService: NoteVersionService
    private let workspaceService: WorkspaceService

    public init(
        noteService: NoteService,
        folderService: FolderService,
        searchService: SearchService,
        tagService: TagService,
        versionService: NoteVersionService,
        workspaceService: WorkspaceService
    ) {
        self.noteService = noteService
        self.folderService = folderService
        self.searchService = searchService
        self.tagService = tagService
        self.versionService = versionService
        self.workspaceService = workspaceService
    }

    /// 起動時に呼び出す。既存のローカルユーザーがあれば復元し、なければログイン画面へ遷移する。
    public func bootstrap() async {
        do {
            if let user = try await workspaceService.existingUser() {
                currentUser = user
                currentWorkspace = try await workspaceService.personalWorkspace(for: user)
                phase = .ready
                await runStartupMaintenance()
            } else {
                phase = .login
            }
        } catch {
            errorMessage = "起動処理に失敗しました: \(error.localizedDescription)"
            phase = .login
        }
    }

    /// 「ローカルユーザーで開始」操作。ローカルユーザーと個人ワークスペースを生成する。
    public func startAsLocalUser() async {
        do {
            let result = try await workspaceService.startAsLocalUser()
            currentUser = result.user
            currentWorkspace = result.workspace
            phase = .ready
            await runStartupMaintenance()
        } catch {
            errorMessage = "ローカルユーザーの作成に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 起動時のメンテナンスを実行する。失敗しても致命的とはみなさず、次回起動時に再試行する。
    private func runStartupMaintenance() async {
        await purgeExpiredTrash()
        await purgeExpiredVersions()
    }

    /// 保持期間を過ぎたゴミ箱内ノートを削除する（F-ORG-05、30日保持）。
    private func purgeExpiredTrash() async {
        guard let workspace = currentWorkspace else { return }
        try? await noteService.purgeExpiredTrash(in: workspace.id)
    }

    /// 保持期間を過ぎたバージョン履歴を削除する（F-EDIT-08、30日保持）。
    private func purgeExpiredVersions() async {
        try? await versionService.purgeExpired()
    }
}
