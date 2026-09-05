import Domain
import Repository

/// お気に入りの一覧そのものを購読する。お気に入り画面が使う。
public struct ObserveFavoritesUseCase: Sendable {
    private let repository: any FavoriteRepository

    public init(repository: any FavoriteRepository) {
        self.repository = repository
    }

    public func callAsFunction() async -> AsyncStream<[FavoriteRepo]> {
        await repository.stream()
    }
}
