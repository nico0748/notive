import Foundation

/// アプリ利用者を表すドメインエンティティ。
///
/// 本イテレーションでは認証バックエンドを持たないため、`isLocal == true` の
/// ローカルユーザーのみを扱う（F-AUTH 系はスタブ）。
public struct User: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var displayName: String
    /// 認証導入後に使用する。ローカルユーザーでは `nil`。
    public var email: String?
    /// バックエンド未接続のローカル専用ユーザーかどうか。
    public var isLocal: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        email: String? = nil,
        isLocal: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.isLocal = isLocal
        self.createdAt = createdAt
    }

    /// 「ローカルユーザーで開始」用の既定ユーザーを生成する。
    public static func makeLocal() -> User {
        User(displayName: NotesConstants.Naming.localUserDisplayName, isLocal: true)
    }
}
