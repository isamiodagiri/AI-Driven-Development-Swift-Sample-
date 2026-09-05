import Domain
import Repository

/// いまのお気に入りを1回だけ読む。**API は呼ばない**（保存してある要約をそのまま返す ＝ AC-21）。
public struct ListFavoriteReposUseCase: Sendable {
    private let repository: any FavoriteRepository

    public init(repository: any FavoriteRepository) {
        self.repository = repository
    }

    public func callAsFunction() async -> [FavoriteRepo] {
        await repository.favorites()
    }
}
