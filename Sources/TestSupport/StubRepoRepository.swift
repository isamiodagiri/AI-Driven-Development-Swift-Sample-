import Domain
import Foundation
import Repository

/// `RepoRepository` の差し替え。**呼ばれた引数を記録する**
/// — 「呼ばれていない」（AC-1・AC-24）を観測できる形にしておく必要がある。
public actor StubRepoRepository: RepoRepository {
    public struct SearchCall: Sendable, Equatable {
        public let query: String
        public let page: Int

        public init(query: String, page: Int) {
            self.query = query
            self.page = page
        }
    }

    /// `Result` を使わないのは、`Result<_, any Error>` が `Sendable` にならないためである
    /// （actor の口に渡せない）。失敗の型に `& Sendable` を要求する形にしてある。
    public enum SearchOutcome: Sendable {
        case success(RepoPage)
        case failure(any Error & Sendable)
    }

    public enum DetailOutcome: Sendable {
        case success(RepoDetail)
        case failure(any Error & Sendable)
    }

    public private(set) var searchCalls: [SearchCall] = []
    public private(set) var detailCalls: [String] = []

    private var searchResults: [Int: SearchOutcome] = [:]
    private var defaultSearchResult: SearchOutcome?
    private var detailResult: DetailOutcome?

    public init() {}

    public func setSearchResult(_ result: SearchOutcome, forPage page: Int? = nil) {
        if let page {
            searchResults[page] = result
        } else {
            defaultSearchResult = result
        }
    }

    public func setDetailResult(_ result: DetailOutcome) {
        detailResult = result
    }

    public func search(query: SearchQuery, page: Int) async throws -> RepoPage {
        searchCalls.append(SearchCall(query: query.rawValue, page: page))
        guard let result = searchResults[page] ?? defaultSearchResult else {
            return RepoPage(items: [], totalCount: 0, page: page, hasMore: false)
        }
        switch result {
        case .success(let page): return page
        case .failure(let error): throw error
        }
    }

    public func fetchDetail(owner: String, name: String) async throws -> RepoDetail {
        detailCalls.append("\(owner)/\(name)")
        guard let detailResult else {
            throw GitHubError.unknown
        }
        switch detailResult {
        case .success(let detail): return detail
        case .failure(let error): throw error
        }
    }
}
