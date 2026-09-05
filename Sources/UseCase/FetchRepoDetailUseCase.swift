import Domain
import Repository

/// 詳細の取得。**薄いが省かない** — 層を飛ばす例外を1つ許すと、そこが前例になる（UC-002 §5）。
public struct FetchRepoDetailUseCase: Sendable {
    private let repository: any RepoRepository

    public init(repository: any RepoRepository) {
        self.repository = repository
    }

    public func callAsFunction(owner: String, name: String) async throws -> RepoDetail {
        try await repository.fetchDetail(owner: owner, name: name)
    }
}
