import Core
import DesignSystem
import Domain
import Foundation
import Repository
import Testing
import TestSupport
import UseCase

@testable import SearchFeature

/// UC-001 の ViewModel テストが共有する道具立て。
///
/// Suite を2つに分けてある（検索本体と、追加読み込み以降）ので、SUT の組み立てはここに置く。
/// debounce の間隔は注入して短くしてある。時間そのものを待つテストにはしない
/// （docs/04-test-strategy.md §5-1）。
@MainActor
enum SearchFixture {
    nonisolated static let now = Date(timeIntervalSince1970: 1_756_000_000)
    static let debounce = DispatchQueue.SchedulerTimeType.Stride.milliseconds(50)

    struct SUT {
        let viewModel: SearchViewModel
        let client: StubHTTPClient
        let favorites: FavoriteRepositoryImpl
    }

    static func makeSUT() -> SUT {
        let client = StubHTTPClient()
        let repoRepository = RepoRepositoryImpl(client: client, now: { now })
        let favorites = FavoriteRepositoryImpl(store: InMemoryKeyValueStore(), now: { now })
        let viewModel = SearchViewModel(
            searchRepos: SearchReposUseCase(repository: repoRepository),
            loadMoreRepos: LoadMoreReposUseCase(repository: repoRepository),
            toggleFavorite: ToggleFavoriteUseCase(repository: favorites),
            observeFavoriteIDs: ObserveFavoriteIDsUseCase(repository: favorites),
            now: { now },
            debounceInterval: debounce,
            scheduler: .main
        )
        viewModel.onAppear()
        return SUT(viewModel: viewModel, client: client, favorites: favorites)
    }

    static func rows(_ phase: SearchPhase) -> [SearchRow] {
        if case .loaded(let rows, _) = phase { return rows }
        return []
    }

    /// 1ページ目まで読み終えた状態を作る。
    static func loadedSUT(
        gateSecondPage: Bool = false,
        secondPageIgnoresCancellation: Bool = false,
        secondPageOutcome: StubHTTPClient.Outcome = .success(Fixture.response("search_repositories_page2"))
    ) async -> SUT {
        let sut = makeSUT()
        await sut.client.set(.success(Fixture.response("search_repositories_ok")), forQuery: "swift", page: 1)
        // 2ページ目は同じ検索語なので、ページ番号までキーに含めて分ける
        await sut.client.set(
            secondPageOutcome,
            forQuery: "swift",
            page: 2,
            manualRelease: gateSecondPage,
            ignoresCancellation: secondPageIgnoresCancellation
        )
        sut.viewModel.query = "swift"
        await waitUntilOnMain { rows(sut.viewModel.displayState.phase).count == 30 }
        return sut
    }
}
