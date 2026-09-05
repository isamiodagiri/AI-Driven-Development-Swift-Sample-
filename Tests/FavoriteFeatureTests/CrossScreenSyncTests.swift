import DesignSystem
import Domain
import Foundation
import Presentation
import Repository
import Testing
import TestSupport
import UseCase

@testable import FavoriteFeature
@testable import RepoDetailFeature
@testable import SearchFeature

/// UC-003 の統合（TS-98・TS-99）。
///
/// **お気に入りの真実源は Repository ひとつだけ**（BR-010）であることを、
/// 3つの画面の ViewModel を同時に立てて確かめる。
/// 画面ごとにフラグを持つ実装だと、ここで必ず落ちる。
@MainActor
@Suite("UC-003 統合: 画面をまたぐ反映")
struct CrossScreenSyncTests {
    nonisolated static let now = Date(timeIntervalSince1970: 1_756_000_000)

    struct World {
        let search: SearchViewModel
        let favorite: FavoriteViewModel
        let detail: RepoDetailViewModel
        let client: StubHTTPClient
    }

    static func makeWorld() -> World {
        let client = StubHTTPClient()
        let repoRepository = RepoRepositoryImpl(client: client, now: { now })
        let favorites = FavoriteRepositoryImpl(store: InMemoryKeyValueStore(), now: { now })

        let toggle = ToggleFavoriteUseCase(repository: favorites)
        let observeIDs = ObserveFavoriteIDsUseCase(repository: favorites)

        let search = SearchViewModel(
            searchRepos: SearchReposUseCase(repository: repoRepository),
            loadMoreRepos: LoadMoreReposUseCase(repository: repoRepository),
            toggleFavorite: toggle,
            observeFavoriteIDs: observeIDs,
            now: { now },
            debounceInterval: .milliseconds(50),
            scheduler: .main
        )
        let favorite = FavoriteViewModel(
            observeFavorites: ObserveFavoritesUseCase(repository: favorites),
            toggleFavorite: toggle,
            now: { now }
        )
        let detail = RepoDetailViewModel(
            ownerLogin: "owner-1",
            repoName: "repo-1",
            initialDisplay: RepoDisplayMapper.display(
                for: .stub(id: 1001, name: "repo-1", fullName: "owner-1/repo-1", ownerLogin: "owner-1"),
                isFavorite: false,
                now: now
            ),
            fetchRepoDetail: FetchRepoDetailUseCase(repository: repoRepository),
            toggleFavorite: toggle,
            observeFavoriteIDs: observeIDs,
            now: { now }
        )

        search.onAppear()
        favorite.onAppear()
        detail.onAppear()
        return World(search: search, favorite: favorite, detail: detail, client: client)
    }

    static func searchRows(_ viewModel: SearchViewModel) -> [SearchRow] {
        if case .loaded(let rows, _) = viewModel.displayState.phase { return rows }
        return []
    }

    static func favoriteRows(_ viewModel: FavoriteViewModel) -> [RepoRowDisplay] {
        if case .loaded(let rows) = viewModel.state.phase { return rows }
        return []
    }

    @Test("TS-98 検索で追加すると、お気に入り画面の一覧に即座に現れる")
    func addingFromSearchAppearsInFavorites() async {
        let world = Self.makeWorld()
        await world.client.setDefault(.success(Fixture.response("search_repositories_ok")))
        world.search.query = "swift"
        await waitUntilOnMain { !Self.searchRows(world.search).isEmpty }

        world.search.toggleFavorite(rowID: 1001)

        await waitUntilOnMain { !Self.favoriteRows(world.favorite).isEmpty }
        #expect(Self.favoriteRows(world.favorite).map(\.id) == [1001])
    }

    @Test("TS-99 詳細で追加すると、検索一覧の同じ行が ★ になる")
    func addingFromDetailUpdatesSearchRow() async {
        let world = Self.makeWorld()
        await world.client.set(.success(Fixture.response("search_repositories_ok")), forQuery: "swift")
        await world.client.setDefault(.success(Fixture.response("repo_detail_ok")))
        world.search.query = "swift"
        await waitUntilOnMain { !Self.searchRows(world.search).isEmpty }
        #expect(Self.searchRows(world.search).first?.display.isFavorite == false)

        world.detail.toggleFavorite()

        await waitUntilOnMain { Self.searchRows(world.search).first?.display.isFavorite == true }
        #expect(Self.searchRows(world.search).first?.display.isFavorite == true)
        #expect(world.detail.isFavorite)
    }

    @Test("お気に入り画面で外すと、検索一覧の ★ も ☆ に戻る")
    func removingFromFavoritesUpdatesSearchRow() async {
        let world = Self.makeWorld()
        await world.client.setDefault(.success(Fixture.response("search_repositories_ok")))
        world.search.query = "swift"
        await waitUntilOnMain { !Self.searchRows(world.search).isEmpty }
        world.search.toggleFavorite(rowID: 1001)
        await waitUntilOnMain { Self.searchRows(world.search).first?.display.isFavorite == true }

        world.favorite.remove(rowID: 1001)

        await waitUntilOnMain { Self.searchRows(world.search).first?.display.isFavorite == false }
        #expect(Self.searchRows(world.search).first?.display.isFavorite == false)
        #expect(!world.detail.isFavorite)
    }
}
