import DesignSystem
import Domain
import Foundation
import Presentation
import Repository
import Testing
import TestSupport
import UseCase

@testable import FavoriteFeature

/// UC-003 の ViewModel 層（TS-91〜TS-93）。
@MainActor
@Suite("UC-003 ViewModel: お気に入り")
struct FavoriteViewModelTests {
    nonisolated static let now = Date(timeIntervalSince1970: 1_756_000_000)

    struct SUT {
        let viewModel: FavoriteViewModel
        let favorites: FavoriteRepositoryImpl
        let store: InMemoryKeyValueStore
    }

    static func makeSUT() -> SUT {
        let store = InMemoryKeyValueStore()
        let favorites = FavoriteRepositoryImpl(store: store, now: { now })
        let viewModel = FavoriteViewModel(
            observeFavorites: ObserveFavoritesUseCase(repository: favorites),
            toggleFavorite: ToggleFavoriteUseCase(repository: favorites),
            now: { now }
        )
        viewModel.onAppear()
        return SUT(viewModel: viewModel, favorites: favorites, store: store)
    }

    static func rows(_ phase: FavoritePhase) -> [RepoRowDisplay] {
        if case .loaded(let rows) = phase { return rows }
        return []
    }

    @Test("TS-92 0件なら空状態")
    func showsEmpty() async {
        let sut = Self.makeSUT()

        await waitUntilOnMain { sut.viewModel.state.phase == .empty }
        #expect(sut.viewModel.state.phase == .empty)
    }

    @Test("追加すると一覧に出る。行はお気に入り済みとして描かれる")
    func showsAddedFavorite() async {
        let sut = Self.makeSUT()

        try? await sut.favorites.add(.stub(id: 1))

        await waitUntilOnMain { !Self.rows(sut.viewModel.state.phase).isEmpty }
        let row = Self.rows(sut.viewModel.state.phase).first
        #expect(row?.isFavorite == true)
        #expect(row?.fullName == "apple/swift")
    }

    @Test("TS-91 更新に失敗したら表示は元に戻り、通知が出る")
    func revertsWhenRemoveFails() async {
        let sut = Self.makeSUT()
        try? await sut.favorites.add(.stub(id: 1))
        await waitUntilOnMain { !Self.rows(sut.viewModel.state.phase).isEmpty }
        await sut.store.failNextWrites()

        sut.viewModel.remove(rowID: 1)

        await waitUntilOnMain { sut.viewModel.toast != nil }
        #expect(sut.viewModel.toast != nil)
        // 保存できていないので、一覧はそのまま
        #expect(Self.rows(sut.viewModel.state.phase).count == 1)
    }

    @Test("削除すると一覧から消える")
    func removesFavorite() async {
        let sut = Self.makeSUT()
        try? await sut.favorites.add(.stub(id: 1))
        await waitUntilOnMain { !Self.rows(sut.viewModel.state.phase).isEmpty }

        sut.viewModel.remove(rowID: 1)

        await waitUntilOnMain { sut.viewModel.state.phase == .empty }
        #expect(sut.viewModel.state.phase == .empty)
    }

    @Test("TS-93 更新しても行の識別子は変わらない（作り直さない）")
    func keepsStableRowIdentity() async {
        let sut = Self.makeSUT()
        try? await sut.favorites.add(.stub(id: 1))
        await waitUntilOnMain { !Self.rows(sut.viewModel.state.phase).isEmpty }
        let before = Self.rows(sut.viewModel.state.phase).map(\.id)

        try? await sut.favorites.add(.stub(id: 2))

        await waitUntilOnMain { Self.rows(sut.viewModel.state.phase).count == 2 }
        let after = Self.rows(sut.viewModel.state.phase).map(\.id)
        // 既にあった行の識別子はそのまま（並びの先頭に新しいものが入るだけ）
        #expect(after.contains(before[0]))
        #expect(Set(after) == Set([1, 2]))
    }

    @Test("並びは追加した新しい順（Repository が持つ順序に従う）")
    func ordersByAddedAtDescending() async {
        let store = InMemoryKeyValueStore()
        let clock = MutableClock(start: Self.now)
        let favorites = FavoriteRepositoryImpl(store: store, now: { clock.now })
        let viewModel = FavoriteViewModel(
            observeFavorites: ObserveFavoritesUseCase(repository: favorites),
            toggleFavorite: ToggleFavoriteUseCase(repository: favorites),
            now: { Self.now }
        )
        viewModel.onAppear()

        try? await favorites.add(.stub(id: 1))
        clock.advance(by: 60)
        try? await favorites.add(.stub(id: 2))

        await waitUntilOnMain { Self.rows(viewModel.state.phase).count == 2 }
        #expect(Self.rows(viewModel.state.phase).map(\.id) == [2, 1])
    }
}
