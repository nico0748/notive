import Foundation

/// ワークスペースとローカルユーザーのブートストラップを担うユースケース。
///
/// 本イテレーションでは認証バックエンドを持たないため、「ローカルユーザーで開始」
/// 操作に対応する個人ワークスペースの生成のみを扱う（F-ORG-01 / F-AUTH スタブ）。
@MainActor
public final class WorkspaceService {
    private let userRepository: UserRepository
    private let workspaceRepository: WorkspaceRepository

    public init(userRepository: UserRepository, workspaceRepository: WorkspaceRepository) {
        self.userRepository = userRepository
        self.workspaceRepository = workspaceRepository
    }

    /// 既存のローカルユーザーを返す。未作成なら `nil`。
    public func existingUser() async throws -> User? {
        try await userRepository.currentUser()
    }

    /// 指定ユーザーの個人ワークスペースを返す。存在しなければ生成して永続化する。
    public func personalWorkspace(for user: User) async throws -> Workspace {
        let workspaces = try await workspaceRepository.allWorkspaces()
        if let existing = workspaces.first(where: { $0.ownerID == user.id && $0.kind == .personal }) {
            return existing
        }
        let workspace = Workspace.makePersonal(ownerID: user.id)
        try await workspaceRepository.save(workspace)
        return workspace
    }

    /// ローカルユーザーを新規作成し、その個人ワークスペースとともに返す。
    public func startAsLocalUser() async throws -> (user: User, workspace: Workspace) {
        let user = User.makeLocal()
        try await userRepository.save(user)
        let workspace = try await personalWorkspace(for: user)
        return (user, workspace)
    }
}
