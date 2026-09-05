import Core
import DesignSystem
import Domain
import Foundation
import Repository
import Testing
import TestSupport
import UseCase

@testable import SearchFeature

/// UC-001 の ViewModel 層のうち、追加読み込み・失敗・お気に入り（TS-37〜TS-47・TS-90）。
///
/// 入力と結果は SearchViewModelTests にある。
@MainActor
@Suite("UC-001 ViewModel: 追加読み込みと失敗")
struct SearchViewModelPagingTests {
    // MARK: - 追加読み込み

    @Test("TS-37 末尾に達すると次のページを1回だけ要求する")
    func loadsMoreOnce() async {
        let sut = await SearchFixture.loadedSUT()

        sut.viewModel.onReachedLoadMoreTrigger()
        sut.viewModel.onReachedLoadMoreTrigger()

        await waitUntilOnMain { SearchFixture.rows(sut.viewModel.displayState.phase).count == 60 }
        let count = await sut.client.requestCount
        #expect(count == 2)
    }

    @Test("TS-38 追加読み込み中も既存の行は残る")
    func keepsRowsWhileLoadingMore() async {
        let sut = await SearchFixture.loadedSUT(gateSecondPage: true)

        sut.viewModel.onReachedLoadMoreTrigger()

        await waitUntilOnMain {
            if case .loaded(_, let isLoadingMore) = sut.viewModel.displayState.phase { return isLoadingMore }
            return false
        }
        #expect(SearchFixture.rows(sut.viewModel.displayState.phase).count == 30)
        await sut.client.release("swift#2")
    }

    @Test("TS-39 2ページ目は追記される（置き換えない）")
    func appendsSecondPage() async {
        let sut = await SearchFixture.loadedSUT()

        sut.viewModel.onReachedLoadMoreTrigger()

        await waitUntilOnMain { SearchFixture.rows(sut.viewModel.displayState.phase).count == 60 }
        let rows = SearchFixture.rows(sut.viewModel.displayState.phase)
        #expect(rows.first?.display.fullName == "owner-1/repo-1")
        #expect(rows.last?.display.fullName == "owner-60/repo-60")
    }

    @Test("TS-40 進行中は次の要求を無視する")
    func ignoresConcurrentLoadMore() async {
        let sut = await SearchFixture.loadedSUT(gateSecondPage: true)

        sut.viewModel.onReachedLoadMoreTrigger()
        await waitUntil { await sut.client.requestCount == 2 }
        sut.viewModel.onReachedLoadMoreTrigger()
        await settle()

        let count = await sut.client.requestCount
        #expect(count == 2)
        await sut.client.release("swift#2")
    }

    @Test("TS-41 追加読み込みが失敗しても一覧は消えない")
    func keepsRowsWhenLoadMoreFails() async {
        let sut = await SearchFixture.loadedSUT(secondPageOutcome: .failure(URLError(.notConnectedToInternet)))

        sut.viewModel.onReachedLoadMoreTrigger()

        await waitUntilOnMain { sut.viewModel.toast != nil }
        #expect(SearchFixture.rows(sut.viewModel.displayState.phase).count == 30)
        #expect(sut.viewModel.toast != nil)
    }

    @Test("TS-42 追加読み込み中に検索語が変わったら、そのページは捨てる")
    func discardsLoadMoreAfterQueryChange() async {
        let sut = await SearchFixture.loadedSUT(gateSecondPage: true)
        sut.viewModel.onReachedLoadMoreTrigger()
        // 2ページ目が飛んでから検索語を変える。飛ぶ前だと、捨てる対象が無い
        await waitUntil { await sut.client.requestCount == 2 }

        await sut.client.set(.success(Fixture.response("search_repositories_last_page")), forQuery: "other")
        sut.viewModel.query = "other"
        await waitUntilOnMain { SearchFixture.rows(sut.viewModel.displayState.phase).count == 12 }
        await sut.client.release("swift#2")
        await settle()

        #expect(SearchFixture.rows(sut.viewModel.displayState.phase).count == 12)
    }

    @Test("TS-24b hasMore が false なら、末尾に達しても要求しない")
    func doesNotLoadMoreWhenExhausted() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response("search_repositories_last_page")))
        sut.viewModel.query = "swift"
        await waitUntilOnMain { SearchFixture.rows(sut.viewModel.displayState.phase).count == 12 }

        sut.viewModel.onReachedLoadMoreTrigger()
        await settle()

        let count = await sut.client.requestCount
        #expect(count == 1)
    }

    // MARK: - 失敗

    @Test("TS-43 通信できないときは専用の文言で、再試行できる")
    func showsOfflineError() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.failure(URLError(.notConnectedToInternet)))

        sut.viewModel.query = "swift"

        await waitUntilOnMain { if case .failed = sut.viewModel.displayState.phase { true } else { false } }
        guard case .failed(let error) = sut.viewModel.displayState.phase else {
            Issue.record("failed であるべき")
            return
        }
        #expect(error == .offline)
        #expect(error.isRetryable)
    }

    @Test("TS-44 再試行は同じ検索語でやり直す")
    func retriesWithSameQuery() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.failure(URLError(.notConnectedToInternet)))
        sut.viewModel.query = "swift"
        await waitUntilOnMain { if case .failed = sut.viewModel.displayState.phase { true } else { false } }

        await sut.client.setDefault(.success(Fixture.response("search_repositories_ok")))
        sut.viewModel.retry()

        await waitUntilOnMain { SearchFixture.rows(sut.viewModel.displayState.phase).count == 30 }
        let queries = await sut.client.requestedQueries()
        #expect(queries == ["swift", "swift"])
    }

    @Test("TS-45 レート制限は残り分数を出し、再試行ボタンを出さない")
    func showsRateLimitedWithMinutes() async {
        let sut = SearchFixture.makeSUT()
        let reset = SearchFixture.now.addingTimeInterval(180)
        await sut.client.setDefault(.success(Fixture.response(
            "error_403_rate_limit",
            statusCode: 403,
            headers: ["x-ratelimit-remaining": "0", "x-ratelimit-reset": String(reset.timeIntervalSince1970)]
        )))

        sut.viewModel.query = "swift"

        await waitUntilOnMain { if case .failed = sut.viewModel.displayState.phase { true } else { false } }
        guard case .failed(let error) = sut.viewModel.displayState.phase else {
            Issue.record("failed であるべき")
            return
        }
        #expect(!error.isRetryable)
        #expect(error.message.contains("3 分"))
    }

    @Test("TS-46 reset が無いときは分数を出さない")
    func showsRateLimitedWithoutMinutes() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response(
            "error_403_rate_limit",
            statusCode: 403,
            headers: ["x-ratelimit-remaining": "0"]
        )))

        sut.viewModel.query = "swift"

        await waitUntilOnMain { if case .failed = sut.viewModel.displayState.phase { true } else { false } }
        guard case .failed(let error) = sut.viewModel.displayState.phase else {
            Issue.record("failed であるべき")
            return
        }
        #expect(error.message == "しばらく待ってからお試しください")
        #expect(!error.isRetryable)
    }

    @Test("TS-47 レート制限中に自動で再試行しない")
    func doesNotAutoRetryWhenRateLimited() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response(
            "error_403_rate_limit",
            statusCode: 403,
            headers: ["x-ratelimit-remaining": "0"]
        )))
        sut.viewModel.query = "swift"
        await waitUntilOnMain { if case .failed = sut.viewModel.displayState.phase { true } else { false } }

        await settle(.milliseconds(300))

        let count = await sut.client.requestCount
        #expect(count == 1)
    }

    // MARK: - お気に入り

    @Test("TS-90 外でお気に入りが変わると、一覧の ★ が追随する")
    func reflectsFavoriteChangesFromOutside() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response("search_repositories_ok")))
        sut.viewModel.query = "swift"
        await waitUntilOnMain { !SearchFixture.rows(sut.viewModel.displayState.phase).isEmpty }
        #expect(SearchFixture.rows(sut.viewModel.displayState.phase).first?.display.isFavorite == false)

        try? await sut.favorites.add(.stub(id: 1001))

        await waitUntilOnMain { SearchFixture.rows(sut.viewModel.displayState.phase).first?.display.isFavorite == true }
        #expect(SearchFixture.rows(sut.viewModel.displayState.phase).first?.display.isFavorite == true)
    }

    @Test("一覧の ☆ を押すとお気に入りに入る")
    func togglesFavoriteFromList() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response("search_repositories_ok")))
        sut.viewModel.query = "swift"
        await waitUntilOnMain { !SearchFixture.rows(sut.viewModel.displayState.phase).isEmpty }

        sut.viewModel.toggleFavorite(rowID: 1001)

        await waitUntilOnMain { SearchFixture.rows(sut.viewModel.displayState.phase).first?.display.isFavorite == true }
        let favorites = await sut.favorites.favorites()
        #expect(favorites.map(\.id) == [RepoID(1001)])
    }
}
