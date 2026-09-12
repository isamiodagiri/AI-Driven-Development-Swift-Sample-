import DesignSystem
import Domain
import Foundation
import Presentation
import Repository
import Testing
import TestSupport
import UseCase

@testable import RepoDetailFeature

/// UC-002 の ViewModel 層（TS-58〜TS-71）。
@MainActor
@Suite("UC-002 ViewModel: 詳細")
struct RepoDetailViewModelTests {
    nonisolated static let now = Date(timeIntervalSince1970: 1_756_000_000)

    struct SUT {
        let viewModel: RepoDetailViewModel
        let client: StubHTTPClient
        let favorites: FavoriteRepositoryImpl
    }

    static func display(id: Int = 1001) -> RepoRowDisplay {
        RepoDisplayMapper.display(
            for: .stub(id: id, name: "repo-1", fullName: "owner-1/repo-1", ownerLogin: "owner-1"),
            isFavorite: false,
            now: now
        )
    }

    static func makeSUT(initialDisplay: RepoRowDisplay?) -> SUT {
        let client = StubHTTPClient()
        let repoRepository = RepoRepositoryImpl(client: client, now: { now })
        let favorites = FavoriteRepositoryImpl(store: InMemoryKeyValueStore(), now: { now })
        let viewModel = RepoDetailViewModel(
            ownerLogin: "owner-1",
            repoName: "repo-1",
            initialDisplay: initialDisplay,
            fetchRepoDetail: FetchRepoDetailUseCase(repository: repoRepository),
            toggleFavorite: ToggleFavoriteUseCase(repository: favorites),
            observeFavoriteIDs: ObserveFavoriteIDsUseCase(repository: favorites),
            now: { now }
        )
        return SUT(viewModel: viewModel, client: client, favorites: favorites)
    }

    @Test("TS-58 一覧から来たときは、取得を待たずに基本項目が入っている")
    func showsInitialDisplayBeforeFetch() {
        let sut = Self.makeSUT(initialDisplay: Self.display())

        guard case .partial(let header, let stats, let error) = sut.viewModel.state.phase else {
            Issue.record("partial であるべき")
            return
        }
        #expect(header.display.fullName == "owner-1/repo-1")
        #expect(stats.starsText == "67.0k")
        #expect(stats.watchersText == nil)
        #expect(error == nil)
    }

    @Test("TS-59 取得に成功すると watchers / issues / license / topics が加わる")
    func addsDetailFields() async {
        let sut = Self.makeSUT(initialDisplay: Self.display())
        await sut.client.setDefault(.success(Fixture.response("repo_detail_ok")))

        sut.viewModel.onAppear()

        await waitUntilOnMain { if case .loaded = sut.viewModel.state.phase { true } else { false } }
        guard case .loaded(_, let stats, let fields, let topics) = sut.viewModel.state.phase else {
            Issue.record("loaded であるべき")
            return
        }
        #expect(stats.watchersText == "1.2k")
        #expect(stats.openIssuesText == "340")
        #expect(topics == ["swift", "compiler"])
        #expect(fields.contains { $0.id == "license" && $0.value == "Apache License 2.0" })
    }

    @Test("TS-60 一覧から来た画面で取得に失敗しても、基本項目は残る")
    func keepsHeaderWhenFetchFails() async {
        let sut = Self.makeSUT(initialDisplay: Self.display())
        await sut.client.setDefault(.failure(URLError(.notConnectedToInternet)))

        sut.viewModel.onAppear()

        await waitUntilOnMain {
            if case .partial(_, _, let error) = sut.viewModel.state.phase { return error != nil }
            return false
        }
        guard case .partial(let header, _, let error) = sut.viewModel.state.phase else {
            Issue.record("partial であるべき")
            return
        }
        #expect(header.display.fullName == "owner-1/repo-1")
        #expect(error == .offline)
    }

    @Test("TS-61 一覧の情報が無い画面で取得に失敗すると、画面全体がエラーになる")
    func showsFullErrorWithoutInitialDisplay() async {
        let sut = Self.makeSUT(initialDisplay: nil)
        await sut.client.setDefault(.failure(URLError(.notConnectedToInternet)))

        sut.viewModel.onAppear()

        await waitUntilOnMain { if case .failed = sut.viewModel.state.phase { true } else { false } }
        #expect(sut.viewModel.state.phase == .failed(.offline))
    }

    @Test("TS-62 再試行でもう一度取得する")
    func retriesFetch() async {
        let sut = Self.makeSUT(initialDisplay: nil)
        await sut.client.setDefault(.failure(URLError(.notConnectedToInternet)))
        sut.viewModel.onAppear()
        await waitUntilOnMain { if case .failed = sut.viewModel.state.phase { true } else { false } }

        await sut.client.setDefault(.success(Fixture.response("repo_detail_ok")))
        sut.viewModel.retry()

        await waitUntilOnMain { if case .loaded = sut.viewModel.state.phase { true } else { false } }
        let count = await sut.client.requestCount
        #expect(count == 2)
    }

    @Test("TS-63 404 は再試行させない")
    func notFoundIsNotRetryable() async {
        let sut = Self.makeSUT(initialDisplay: nil)
        await sut.client.setDefault(.success(Fixture.response("error_404_not_found", statusCode: 404)))

        sut.viewModel.onAppear()

        await waitUntilOnMain { if case .failed = sut.viewModel.state.phase { true } else { false } }
        #expect(sut.viewModel.state.phase == .failed(.notFound))
    }

    @Test("TS-64 レート制限は残り分数を出し、再試行させない")
    func rateLimitedShowsMinutes() async {
        let sut = Self.makeSUT(initialDisplay: nil)
        let reset = Self.now.addingTimeInterval(120)
        await sut.client.setDefault(.success(Fixture.response(
            "error_403_rate_limit",
            statusCode: 403,
            headers: ["x-ratelimit-remaining": "0", "x-ratelimit-reset": String(reset.timeIntervalSince1970)]
        )))

        sut.viewModel.onAppear()

        await waitUntilOnMain { if case .failed = sut.viewModel.state.phase { true } else { false } }
        guard case .failed(let error) = sut.viewModel.state.phase else {
            Issue.record("failed であるべき")
            return
        }
        #expect(error.message.contains("2 分"))
        #expect(!error.isRetryable)
    }

    @Test("TS-65 通信できないときは専用の文言")
    func offlineShowsDedicatedMessage() async {
        let sut = Self.makeSUT(initialDisplay: nil)
        await sut.client.setDefault(.failure(URLError(.notConnectedToInternet)))

        sut.viewModel.onAppear()

        await waitUntilOnMain { if case .failed = sut.viewModel.state.phase { true } else { false } }
        #expect(sut.viewModel.state.phase == .failed(.offline))
    }

    @Test("TS-66 画面を閉じると取得は止まる")
    func cancelsFetchOnDisappear() async {
        let sut = Self.makeSUT(initialDisplay: Self.display())
        await sut.client.set(
            .success(Fixture.response("repo_detail_ok")),
            forQuery: "/repos/owner-1/repo-1",
            manualRelease: true
        )
        sut.viewModel.onAppear()
        await waitUntil { await sut.client.requestCount == 1 }

        sut.viewModel.onDisappear()

        // **止めたことそのもの**を見る。「loaded にならない」だけだと、
        // 応答を保留したまま解放していないので、止めていなくても素通りする
        // — TS-34 と同じ穴だった（docs/04-test-strategy.md §6-5）
        await waitUntil { await sut.client.cancelledQueries().contains("/repos/owner-1/repo-1") }
        let cancelled = await sut.client.cancelledQueries()
        #expect(cancelled.contains("/repos/owner-1/repo-1"))

        // 取得は完了していないので、詳細の項目は入っていない
        if case .loaded = sut.viewModel.state.phase {
            Issue.record("閉じたあとに loaded になってはいけない")
        }
        // 止め損ねる実装だと、解放されない要求がテストを跨いで残る
        await sut.client.release("/repos/owner-1/repo-1")
    }

    @Test("TS-67 閉じたあとに応答が届いても状態は変わらない")
    func lateResponseDoesNotUpdateAfterDisappear() async {
        let sut = Self.makeSUT(initialDisplay: Self.display())
        await sut.client.set(
            .success(Fixture.response("repo_detail_ok")),
            forQuery: "/repos/owner-1/repo-1",
            manualRelease: true,
            ignoresCancellation: true
        )
        sut.viewModel.onAppear()
        await waitUntil { await sut.client.requestCount == 1 }
        sut.viewModel.onDisappear()

        await sut.client.release("/repos/owner-1/repo-1")
        // 応答が実際に届いてから見る。届く前に測ると、壊れていても緑になる
        await waitUntil { await sut.client.deliveredQueries().contains("/repos/owner-1/repo-1") }
        await waitForUnwantedOnMain { if case .loaded = sut.viewModel.state.phase { true } else { false } }

        if case .loaded = sut.viewModel.state.phase {
            Issue.record("閉じたあとの応答で状態を書いてはいけない")
        }
    }

    @Test("TS-68 再試行を連打しても、同時に走る取得は1つ")
    func retryDoesNotStackRequests() async {
        let sut = Self.makeSUT(initialDisplay: Self.display())
        await sut.client.set(
            .success(Fixture.response("repo_detail_ok")),
            forQuery: "/repos/owner-1/repo-1",
            manualRelease: true
        )
        sut.viewModel.onAppear()
        await waitUntil { await sut.client.requestCount == 1 }

        sut.viewModel.retry()
        sut.viewModel.retry()
        await waitForUnwanted { await sut.client.requestCount > 2 }
        await sut.client.release("/repos/owner-1/repo-1")
        await waitUntilOnMain { if case .loaded = sut.viewModel.state.phase { true } else { false } }

        // 前を止めてから始めるので、最後の1つだけが結果を書く
        if case .loaded = sut.viewModel.state.phase {} else {
            Issue.record("loaded であるべき")
        }
    }

    @Test("TS-69 ☆ を押すとお気に入りに入る")
    func togglesFavorite() async {
        let sut = Self.makeSUT(initialDisplay: Self.display())
        await sut.client.setDefault(.success(Fixture.response("repo_detail_ok")))
        sut.viewModel.onAppear()
        await waitUntilOnMain { if case .loaded = sut.viewModel.state.phase { true } else { false } }

        sut.viewModel.toggleFavorite()

        await waitUntilOnMain { sut.viewModel.isFavorite }
        let favorites = await sut.favorites.favorites()
        #expect(favorites.map(\.id) == [RepoID(1001)])
    }

    @Test("TS-70 外で外されると ★ が ☆ に戻る")
    func reflectsExternalRemoval() async {
        let sut = Self.makeSUT(initialDisplay: Self.display())
        await sut.client.setDefault(.success(Fixture.response("repo_detail_ok")))
        sut.viewModel.onAppear()
        try? await sut.favorites.add(.stub(id: 1001))
        await waitUntilOnMain { sut.viewModel.isFavorite }

        try? await sut.favorites.remove(id: RepoID(1001))

        await waitUntilOnMain { !sut.viewModel.isFavorite }
        #expect(!sut.viewModel.isFavorite)
    }

    @Test("TS-71 詳細の取得に失敗していてもお気に入りにできる（件数も失われない）")
    func togglesFavoriteEvenWhenDetailFailed() async {
        let sut = Self.makeSUT(initialDisplay: Self.display())
        await sut.client.setDefault(.failure(URLError(.notConnectedToInternet)))
        sut.viewModel.onAppear()
        await waitUntilOnMain {
            if case .partial(_, _, let error) = sut.viewModel.state.phase { return error != nil }
            return false
        }

        sut.viewModel.toggleFavorite()

        await waitUntilOnMain { sut.viewModel.isFavorite }
        let favorites = await sut.favorites.favorites()
        #expect(favorites.first?.summary.stars == 67000)
        #expect(favorites.first?.summary.fullName == "owner-1/repo-1")
    }
}
