import Domain
import Repository

/// お気に入りの付け外し。**いま入っているかを見て決める**ので、呼ぶ側は状態を持たなくてよい。
public struct ToggleFavoriteUseCase: Sendable {
    private let repository: any FavoriteRepository

    public init(repository: any FavoriteRepository) {
        self.repository = repository
    }

    /// - Returns: 操作後にお気に入りであるか。
    @discardableResult
    public func callAsFunction(summary: RepoSummary) async throws -> Bool {
        let current = await repository.favorites()
        if current.contains(where: { $0.id == summary.id }) {
            try await repository.remove(id: summary.id)
            return false
        }
        try await repository.add(summary)
        return true
    }
}
