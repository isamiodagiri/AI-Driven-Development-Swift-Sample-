import DesignSystem
import Domain
import Foundation
import Presentation
import Repository
import SwiftUI
import Testing
import TestSupport
import UseCase
import ViewInspector

@testable import FavoriteFeature
@testable import SearchFeature

/// UC-003 の View 層（TS-95〜TS-97・TS-100）。
///
/// 「State に出ているのに画面に出ていない」だけを狙う（[04 §3](../../docs/04-test-strategy.md)）。
///
/// **スワイプ削除（TS-94）はここに無い。** `ViewInspector` が `.swipeActions` の中に
/// 届かないためである（[04 §3-1](../../docs/04-test-strategy.md)）。
@MainActor
@Suite("UC-003 View: お気に入り")
struct FavoriteScreenViewTests {
    @Test("TS-95 ★ を押すと削除でき、確認ダイアログは出ない")
    func removesRowByStarTapWithoutConfirmation() async throws {
        let sut = try await Self.loadedSUT()

        let screen = FavoriteScreen(makeViewModel: { sut.viewModel }, onSelectRepo: { _ in })
        let button = try screen.inspect()
            .find(viewWithAccessibilityIdentifier: AppIdentifier.repoRowFavoriteButton)
        try button.button().tap()

        // **消えたことを主張する。** 待つだけだと、消えなくても時間切れで緑になる
        // — 変異検証で実際に素通りした（docs/04-test-strategy.md §6-6）
        await waitUntilOnMain { FavoriteViewModelTests.rows(sut.viewModel.state.phase).isEmpty }
        #expect(FavoriteViewModelTests.rows(sut.viewModel.state.phase).isEmpty)

        // 確認を挟まないのが AC-6 である。挟んでいれば alert / confirmationDialog が居る
        #expect(try screen.inspect().findAll(ViewType.Alert.self).isEmpty)
        #expect(try screen.inspect().findAll(ViewType.ConfirmationDialog.self).isEmpty)
    }

    @Test("TS-96 行をタップすると onSelectRepo が呼ばれる（summary を持たない入口）")
    func callsOnSelectRepoFromFavorite() async throws {
        let sut = try await Self.loadedSUT()
        let selected = Box<RepoRowDisplay?>(nil)

        let screen = FavoriteScreen(makeViewModel: { sut.viewModel }, onSelectRepo: { selected.value = $0 })
        try screen.inspect().find(AppRepoRow.self).callOnTapGesture()

        #expect(selected.value?.id == 1)
    }

    @Test("TS-97 検索とお気に入りは、同じ DesignSystem の行部品を描く")
    func bothScreensUseTheSameRowComponent() async throws {
        let favorite = try await Self.loadedSUT()
        let search = await Self.loadedSearch()

        let favoriteScreen = FavoriteScreen(makeViewModel: { favorite.viewModel }, onSelectRepo: { _ in })
        let searchScreen = SearchScreen(makeViewModel: { search.viewModel }, onSelectRepo: { _ in })

        // 型そのものが同じであることを見る。**同じ見た目を2回書いていない**ことの検査である
        #expect(throws: Never.self) { try favoriteScreen.inspect().find(AppRepoRow.self) }
        #expect(throws: Never.self) { try searchScreen.inspect().find(AppRepoRow.self) }
    }

    @Test("TS-100 ☆ / ★ の表示が、お気に入りの状態に追随する")
    func starReflectsFavoriteState() async throws {
        let sut = await Self.loadedSearch()

        let screen = SearchScreen(makeViewModel: { sut.viewModel }, onSelectRepo: { _ in })
        #expect(try Self.starImageName(in: screen) == "star")

        let rowID = try #require(Self.searchRows(sut.viewModel).first).display.id
        sut.viewModel.toggleFavorite(rowID: rowID)
        await waitUntilOnMain { Self.searchRows(sut.viewModel).first?.display.isFavorite == true }

        // State が変わっただけでは足りない。**画面の記号が変わっている**ことを見る
        #expect(try Self.starImageName(in: screen) == "star.fill")
    }

    // MARK: - 補助

    struct SUT {
        let viewModel: FavoriteViewModel
        let favorites: FavoriteRepositoryImpl
    }

    /// お気に入りが1件だけ入った状態の画面を作る。
    static func loadedSUT() async throws -> SUT {
        let favorites = FavoriteRepositoryImpl(store: InMemoryKeyValueStore(), now: { FavoriteViewModelTests.now })
        try await favorites.add(.stub(id: 1))
        let viewModel = FavoriteViewModel(
            observeFavorites: ObserveFavoritesUseCase(repository: favorites),
            toggleFavorite: ToggleFavoriteUseCase(repository: favorites),
            now: { FavoriteViewModelTests.now }
        )
        viewModel.onAppear()
        await waitUntilOnMain { FavoriteViewModelTests.rows(viewModel.state.phase).count == 1 }
        return SUT(viewModel: viewModel, favorites: favorites)
    }

    struct SearchSUT {
        let viewModel: SearchViewModel
    }

    /// 1ページ目まで読み終えた検索画面。
    ///
    /// `SearchFixture` は SearchFeatureTests のもので、このターゲットからは見えない
    /// （テストターゲット同士も参照できない）。**組み立てはここで持つ。**
    static func loadedSearch() async -> SearchSUT {
        let client = StubHTTPClient()
        let repoRepository = RepoRepositoryImpl(client: client, now: { FavoriteViewModelTests.now })
        let favorites = FavoriteRepositoryImpl(store: InMemoryKeyValueStore(), now: { FavoriteViewModelTests.now })
        let viewModel = SearchViewModel(
            searchRepos: SearchReposUseCase(repository: repoRepository),
            loadMoreRepos: LoadMoreReposUseCase(repository: repoRepository),
            toggleFavorite: ToggleFavoriteUseCase(repository: favorites),
            observeFavoriteIDs: ObserveFavoriteIDsUseCase(repository: favorites),
            now: { FavoriteViewModelTests.now },
            debounceInterval: .milliseconds(50),
            scheduler: .main
        )
        viewModel.onAppear()
        await client.setDefault(.success(Fixture.response("search_repositories_ok")))
        viewModel.query = "swift"
        await waitUntilOnMain { !searchRows(viewModel).isEmpty }
        return SearchSUT(viewModel: viewModel)
    }

    static func searchRows(_ viewModel: SearchViewModel) -> [SearchRow] {
        if case .loaded(let rows, _) = viewModel.displayState.phase { return rows }
        return []
    }

    static func starImageName(in screen: some View) throws -> String {
        try screen.inspect()
            .find(viewWithAccessibilityIdentifier: AppIdentifier.repoRowFavoriteButton)
            .button()
            .labelView()
            .image()
            .actualImage()
            .name()
    }
}

/// クロージャが受け取った値を持ち帰るための入れ物。
@MainActor
final class Box<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
