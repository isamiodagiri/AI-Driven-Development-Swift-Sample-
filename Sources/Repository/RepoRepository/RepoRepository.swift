import Domain

/// GitHub の公開リポジトリを読む口。データアクセスの単一窓口である。
public protocol RepoRepository: Sendable {
    func search(query: SearchQuery, page: Int) async throws -> RepoPage
    func fetchDetail(owner: String, name: String) async throws -> RepoDetail
}
