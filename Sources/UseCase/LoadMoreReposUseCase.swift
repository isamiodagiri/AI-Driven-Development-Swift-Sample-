import Domain
import Repository

/// 次のページ。**要求してよいかの判断はここが持つ**（Repository は材料を返すだけ ＝ BR-005）。
public struct LoadMoreReposUseCase: Sendable {
    /// Search API が返す上限。ここを超えて要求すると 422 になる。
    public static let resultLimit = 1000
    public static let perPage = 30

    private let repository: any RepoRepository

    public init(repository: any RepoRepository) {
        self.repository = repository
    }

    /// - Parameters:
    ///   - loadedCount: すでに手元にある件数
    ///   - hasMore: 直前のページが「まだある」と言っていたか
    /// - Returns: 要求してよくないときは `nil`。呼ばなかったことを表す。
    public func callAsFunction(
        rawQuery: String,
        nextPage: Int,
        loadedCount: Int,
        hasMore: Bool
    ) async throws -> RepoPage? {
        guard hasMore else { return nil }
        guard loadedCount < Self.resultLimit else { return nil }
        guard let query = SearchQuery(rawQuery) else { return nil }
        return try await repository.search(query: query, page: nextPage)
    }
}
