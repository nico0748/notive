import Foundation

/// ノートの検索を担うユースケース（F-SEARCH-01）。
///
/// 本イテレーションではタイトルと本文に対する単純な部分一致検索を提供する。
/// タグ・日付などのフィルタ検索（F-SEARCH-02）は後続イテレーションで拡張する。
public final class SearchService {
    private let repository: NoteRepository

    public init(repository: NoteRepository) {
        self.repository = repository
    }

    /// 指定ワークスペース内で、タイトル・本文がクエリに部分一致するノートを返す。
    ///
    /// - Parameters:
    ///   - query: 検索文字列。空文字の場合はゴミ箱を除く全ノートを返す。
    ///   - workspaceID: 検索対象のワークスペース。
    ///   - includeTrashed: ゴミ箱内のノートを含めるか。既定は `false`。
    public func search(
        query: String,
        in workspaceID: UUID,
        includeTrashed: Bool = false
    ) async throws -> [Note] {
        let notes = try await repository.allNotes(workspaceID: workspaceID)
        return notes
            .filter { includeTrashed || !$0.isTrashed }
            .filter { $0.matches(query: query) }
    }
}
