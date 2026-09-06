import Core
import DesignSystem
import Domain
import Foundation
import Repository
import Testing
import TestSupport
import UseCase

@testable import SearchFeature

/// UC-001 の ViewModel 層のうち、入力・結果・キャンセル（TS-25〜TS-36）。
///
/// 追加読み込み以降は SearchViewModelPagingTests にある。
@MainActor
@Suite("UC-001 ViewModel: 検索")
struct SearchViewModelTests {
    // MARK: - 入力と debounce

    @Test("TS-25 入力後 debounce が経つと検索が1回始まる")
    func startsSearchAfterDebounce() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response("search_repositories_ok")))

        sut.viewModel.query = "swift"

        await waitUntilOnMain { if case .loaded = sut.viewModel.displayState.phase { true } else { false } }
        let count = await sut.client.requestCount
        #expect(count == 1)
    }

    @Test("TS-26 debounce の内側で3回入力しても、呼び出しは1回")
    func coalescesRapidInput() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response("search_repositories_ok")))

        sut.viewModel.query = "s"
        sut.viewModel.query = "sw"
        sut.viewModel.query = "swi"

        // 「1回来た」までは待ち、「それ以上来ない」だけを settle で見る。
        // settle だけで済ませると、debounce が明ける前に測ってしまい負荷で落ちる
        await waitUntil { await sut.client.requestCount == 1 }
        await settle()

        let queries = await sut.client.requestedQueries()
        #expect(queries == ["swi"])
    }

    @Test("TS-27 同じ語に戻ったら呼び直さない")
    func skipsDuplicateQuery() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response("search_repositories_ok")))

        sut.viewModel.query = "swift"
        await waitUntilOnMain { if case .loaded = sut.viewModel.displayState.phase { true } else { false } }
        sut.viewModel.query = "swift"
        await settle()

        let count = await sut.client.requestCount
        #expect(count == 1)
    }

    @Test("TS-28 空になったら initial に戻り、進行中は止まる")
    func returnsToInitialWhenCleared() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response("search_repositories_ok")))
        sut.viewModel.query = "swift"
        await waitUntilOnMain { if case .loaded = sut.viewModel.displayState.phase { true } else { false } }

        sut.viewModel.query = ""

        await waitUntilOnMain { sut.viewModel.displayState.phase == .initial }
        #expect(sut.viewModel.displayState.phase == .initial)
    }

    @Test("TS-29 空にしたあとに古い応答が届いても initial のまま")
    func lateResponseDoesNotRevertInitial() async {
        let sut = SearchFixture.makeSUT()
        // キャンセルされても返り切る応答にして、「cancel が間に合わなかった」状況を作る
        await sut.client.set(
            .success(Fixture.response("search_repositories_ok")),
            forQuery: "swift",
            manualRelease: true,
            ignoresCancellation: true
        )
        sut.viewModel.query = "swift"
        await waitUntilOnMain { if case .loading = sut.viewModel.displayState.phase { true } else { false } }

        sut.viewModel.query = ""
        await waitUntilOnMain { sut.viewModel.displayState.phase == .initial }
        await sut.client.release("swift")
        await settle()

        #expect(sut.viewModel.displayState.phase == .initial)
    }

    @Test("空白だけの入力でも検索しない")
    func doesNotSearchWhitespaceOnly() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response("search_repositories_ok")))

        sut.viewModel.query = "   "

        await settle()
        let count = await sut.client.requestCount
        #expect(count == 0)
        #expect(sut.viewModel.displayState.phase == .initial)
    }

    // MARK: - 結果

    @Test("TS-30 検索中は loading")
    func showsLoadingWhileSearching() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.set(
            .success(Fixture.response("search_repositories_ok")),
            forQuery: "swift",
            manualRelease: true
        )

        sut.viewModel.query = "swift"

        await waitUntilOnMain { sut.viewModel.displayState.phase == .loading }
        #expect(sut.viewModel.displayState.phase == .loading)
        await sut.client.release("swift")
    }

    @Test("TS-31 0件なら empty に検索語が入る")
    func showsEmptyWithQuery() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response("search_repositories_empty")))

        sut.viewModel.query = "存在しない語"

        await waitUntilOnMain { sut.viewModel.displayState.phase == .empty(query: "存在しない語") }
        #expect(sut.viewModel.displayState.phase == .empty(query: "存在しない語"))
    }

    @Test("TS-32 スター数は 1000 以上で k 表記、未満はそのまま")
    func formatsStarCount() {
        #expect(CountText.compact(67000) == "67.0k")
        #expect(CountText.compact(1500) == "1.5k")
        #expect(CountText.compact(999) == "999")
        #expect(CountText.compact(0) == "0")
    }

    @Test("TS-33 7日以内は相対表記、それ以前は yyyy/MM/dd")
    func formatsUpdatedAt() {
        let now = Date(timeIntervalSince1970: 1_756_000_000)
        let threeDaysAgo = now.addingTimeInterval(-3 * 86400)
        let eightDaysAgo = now.addingTimeInterval(-8 * 86400)

        #expect(RelativeDateText.text(for: threeDaysAgo, now: now) == "3日前")
        #expect(RelativeDateText.text(for: eightDaysAgo, now: now).contains("/"))
        #expect(RelativeDateText.text(for: nil, now: now).isEmpty)
    }

    @Test("行には整形済みの文字列が入る")
    func rowCarriesFormattedText() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.setDefault(.success(Fixture.response("search_repositories_ok")))

        sut.viewModel.query = "swift"

        await waitUntilOnMain { !SearchFixture.rows(sut.viewModel.displayState.phase).isEmpty }
        let first = SearchFixture.rows(sut.viewModel.displayState.phase).first
        #expect(first?.display.starsText == "67.0k")
        #expect(first?.display.fullName == "owner-1/repo-1")
    }

    // MARK: - キャンセルと順序

    @Test("TS-34b 新しい検索が始まると、前の要求が実際にキャンセルされる", .timeLimit(.minutes(1)))
    func actuallyCancelsPreviousRequest() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.set(.success(Fixture.response("search_repositories_ok")), forQuery: "swi", manualRelease: true)
        await sut.client.set(.success(Fixture.response("search_repositories_last_page")), forQuery: "swift")

        sut.viewModel.query = "swi"
        await waitUntilOnMain { sut.viewModel.displayState.phase == .loading }
        sut.viewModel.query = "swift"

        // **止めたことそのもの**を見る。TS-34 は「新しい結果が残る」しか見ておらず、
        // 世代番号だけでも緑になってしまう（docs/04-test-strategy.md §6-3）
        await waitUntil { await sut.client.cancelledQueries().contains("swi") }
        let cancelled = await sut.client.cancelledQueries()

        // 先に解放しておく。cancel されない実装では保留の要求が残り続け、
        // **テストが赤ではなく「止まったまま」になる**（docs/04-test-strategy.md §6-3）
        await sut.client.release("swi")
        #expect(cancelled.contains("swi"))
    }

    @Test("TS-34 新しい検索が始まると、前の検索は止まる")
    func cancelsPreviousSearch() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.set(.success(Fixture.response("search_repositories_ok")), forQuery: "swi", manualRelease: true)
        await sut.client.set(.success(Fixture.response("search_repositories_last_page")), forQuery: "swift")

        sut.viewModel.query = "swi"
        await waitUntilOnMain { sut.viewModel.displayState.phase == .loading }
        sut.viewModel.query = "swift"

        // 前の検索は解放していないが、キャンセルされるので画面は新しい結果になる
        await waitUntilOnMain { SearchFixture.rows(sut.viewModel.displayState.phase).count == 12 }
        #expect(SearchFixture.rows(sut.viewModel.displayState.phase).count == 12)
    }

    @Test("TS-35 古い応答が後から届いても、新しい結果が残る")
    func staleResponseDoesNotOverwrite() async {
        let sut = SearchFixture.makeSUT()
        // 古いほうは「キャンセルが間に合わなかった」ことにする
        await sut.client.set(
            .success(Fixture.response("search_repositories_ok")),
            forQuery: "swi",
            manualRelease: true,
            ignoresCancellation: true
        )
        await sut.client.set(
            .success(Fixture.response("search_repositories_last_page")),
            forQuery: "swift",
            manualRelease: true,
            ignoresCancellation: true
        )

        sut.viewModel.query = "swi"
        await waitUntilOnMain { sut.viewModel.displayState.phase == .loading }
        sut.viewModel.query = "swift"
        // 2本目が実際に飛ぶまで待つ。飛ぶ前に release すると、外す相手が居ない
        await waitUntil { await sut.client.requestCount == 2 }

        // 新しいほうを先に返し、古いほうを後から返す
        await sut.client.release("swift")
        await waitUntilOnMain { SearchFixture.rows(sut.viewModel.displayState.phase).count == 12 }
        await sut.client.release("swi")
        await settle()

        #expect(SearchFixture.rows(sut.viewModel.displayState.phase).count == 12)
    }

    @Test("TS-36 キャンセルは失敗にしない（状態を変えない）")
    func cancellationDoesNotBecomeError() async {
        let sut = SearchFixture.makeSUT()
        await sut.client.set(.failure(CancellationError()), forQuery: "swift")

        sut.viewModel.query = "swift"
        await waitUntilOnMain { sut.viewModel.displayState.phase == .loading }
        await settle()

        // キャンセルが失敗に化けるなら、ここで .failed に変わっている
        #expect(sut.viewModel.displayState.phase == .loading)
    }
}
