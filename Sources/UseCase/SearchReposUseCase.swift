import Domain
import Repository

/// 検索の1ページ目。**検索語の検証はここでする**（空・空白のみでは Repository を呼ばない）。
public struct SearchReposUseCase: Sendable {
    private let repository: any RepoRepository

    public init(repository: any RepoRepository) {
        self.repository = repository
    }

    /// - Returns: 検索語が空（空白だけを含む）なら `nil`。呼ばなかったことを表す。
    public func callAsFunction(rawQuery: String) async throws -> RepoPage? {
        guard let query = SearchQuery(rawQuery) else { return nil }
        return try await repository.search(query: query, page: 1)
    }
}
