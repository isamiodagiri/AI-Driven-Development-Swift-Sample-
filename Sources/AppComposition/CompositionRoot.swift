import Core
import DesignSystem
import Domain
import FavoriteFeature
import Foundation
import RepoDetailFeature
import Repository
import SearchFeature
import UseCase

/// 依存の合成はここだけで行う（docs/01-architecture.md §6）。
/// Repository の実装を差し替えられるのも、ここだけである。
public struct AppDependencies: Sendable {
    public let searchRepos: SearchReposUseCase
    public let loadMoreRepos: LoadMoreReposUseCase
    public let fetchRepoDetail: FetchRepoDetailUseCase
    public let toggleFavorite: ToggleFavoriteUseCase
    public let observeFavoriteIDs: ObserveFavoriteIDsUseCase
    public let observeFavorites: ObserveFavoritesUseCase
    public let listFavorites: ListFavoriteReposUseCase

    public init(
        searchRepos: SearchReposUseCase,
        loadMoreRepos: LoadMoreReposUseCase,
        fetchRepoDetail: FetchRepoDetailUseCase,
        toggleFavorite: ToggleFavoriteUseCase,
        observeFavoriteIDs: ObserveFavoriteIDsUseCase,
        observeFavorites: ObserveFavoritesUseCase,
        listFavorites: ListFavoriteReposUseCase
    ) {
        self.searchRepos = searchRepos
        self.loadMoreRepos = loadMoreRepos
        self.fetchRepoDetail = fetchRepoDetail
        self.toggleFavorite = toggleFavorite
        self.observeFavoriteIDs = observeFavoriteIDs
        self.observeFavorites = observeFavorites
        self.listFavorites = listFavorites
    }
}

public enum CompositionRoot {
    /// 本番の結線。
    ///
    /// - Parameter token: 任意。無ければ未認証で動く（検索 10 回/分・その他 60 回/時）。
    ///   **バンドルに埋めたトークンは取り出せるので、配布するアプリでこの方式を採ってはならない**
    ///   （docs/02-github-api.md §5）。
    public static func live(token: String? = nil) -> AppDependencies {
        let repoRepository = RepoRepositoryImpl(client: URLSessionHTTPClient(), token: token)
        let favoriteRepository = FavoriteRepositoryImpl(store: UserDefaultsKeyValueStore())
        return AppDependencies(
            searchRepos: SearchReposUseCase(repository: repoRepository),
            loadMoreRepos: LoadMoreReposUseCase(repository: repoRepository),
            fetchRepoDetail: FetchRepoDetailUseCase(repository: repoRepository),
            toggleFavorite: ToggleFavoriteUseCase(repository: favoriteRepository),
            observeFavoriteIDs: ObserveFavoriteIDsUseCase(repository: favoriteRepository),
            observeFavorites: ObserveFavoritesUseCase(repository: favoriteRepository),
            listFavorites: ListFavoriteReposUseCase(repository: favoriteRepository)
        )
    }

    /// `Info.plist` に取り込んだ `GITHUB_TOKEN` を読む（`App/Config.xcconfig` 経由）。
    public static func tokenFromBundle(_ bundle: Bundle = .main) -> String? {
        guard let token = bundle.object(forInfoDictionaryKey: "GITHUB_TOKEN") as? String, !token.isEmpty else {
            return nil
        }
        return token
    }
}
