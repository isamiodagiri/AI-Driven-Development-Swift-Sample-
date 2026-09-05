import Domain
import Repository

/// お気に入りの ID だけを購読する。一覧・詳細が ★ の表示に使う。
public struct ObserveFavoriteIDsUseCase: Sendable {
    private let repository: any FavoriteRepository

    public init(repository: any FavoriteRepository) {
        self.repository = repository
    }

    public func callAsFunction() async -> AsyncStream<Set<RepoID>> {
        let source = await repository.stream()
        return AsyncStream { continuation in
            let task = Task {
                for await items in source {
                    continuation.yield(Set(items.map(\.id)))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
