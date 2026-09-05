import Combine
import DesignSystem
import Domain
import Foundation
import Presentation
import UseCase

/// 検索画面の状態機械。
///
/// - 入力の debounce と派生状態の合成に **Combine** を使う
/// - 取得の境界は **async/await**。前の検索は必ず `cancel()` する
/// - `cancel()` だけでは足りないので、**世代番号**でも古い応答を弾く（BR-004）
@MainActor
public final class SearchViewModel: ObservableObject {
    /// View から双方向で結ぶ入力。
    @Published public var query: String = ""

    /// お気に入りを反映する前の状態。
    @Published public private(set) var state = SearchState()
    /// お気に入りの ID（Repository が真実源。ここは写しである）。
    @Published public private(set) var favoriteIDs: Set<Int> = []
    /// View が描くのはこちら。`state` と `favoriteIDs` を合成した結果である。
    @Published public private(set) var displayState = SearchState()
    /// 一時的な通知（追加読み込みの失敗など）。一覧は消さない（BR-006）。
    @Published public var toast: String?

    private let searchRepos: SearchReposUseCase
    private let loadMoreRepos: LoadMoreReposUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private let observeFavoriteIDs: ObserveFavoriteIDsUseCase
    private let now: @Sendable () -> Date
    private let debounceInterval: DispatchQueue.SchedulerTimeType.Stride
    private let scheduler: DispatchQueue

    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    private var favoriteTask: Task<Void, Never>?

    /// 検索の世代。応答が状態を書けるのは、自分が最新であるときだけ（BR-004）。
    private var generation = 0
    private var currentQuery = ""
    private var nextPage = 2
    private var loadedCount = 0
    private var hasMore = false
    private var summaries: [Int: RepoSummary] = [:]
    /// 表示している順そのもの。追加読み込みは**追記**なので、順序を持つ配列が要る（AC-22）。
    private var orderedSummaries: [RepoSummary] = []
    private var isStarted = false

    public init(
        searchRepos: SearchReposUseCase,
        loadMoreRepos: LoadMoreReposUseCase,
        toggleFavorite: ToggleFavoriteUseCase,
        observeFavoriteIDs: ObserveFavoriteIDsUseCase,
        now: @escaping @Sendable () -> Date = { Date() },
        debounceInterval: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300),
        scheduler: DispatchQueue = .main
    ) {
        self.searchRepos = searchRepos
        self.loadMoreRepos = loadMoreRepos
        toggleFavoriteUseCase = toggleFavorite
        self.observeFavoriteIDs = observeFavoriteIDs
        self.now = now
        self.debounceInterval = debounceInterval
        self.scheduler = scheduler
    }

    // MARK: - 画面から

    public func onAppear() {
        guard !isStarted else { return }
        isStarted = true
        bindQuery()
        bindDisplayState()
        observeFavorites()
    }

    public func onReachedLoadMoreTrigger() {
        loadMore()
    }

    public func retry() {
        startSearch(currentQuery)
    }

    public func toggleFavorite(rowID: Int) {
        guard let summary = summaries[rowID] else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await toggleFavoriteUseCase(summary: summary)
            } catch {
                // 保存できなかったら、表示は元に戻る（購読が真実源を流し直す ＝ BR-012）
                toast = "お気に入りを保存できませんでした"
            }
        }
    }

    // MARK: - Combine の結線

    private func bindQuery() {
        $query
            .debounce(for: debounceInterval, scheduler: scheduler)
            .removeDuplicates()
            .sink { [weak self] text in
                // scheduler は必ず main。sink はそこで呼ばれる。
                MainActor.assumeIsolated {
                    self?.startSearch(text)
                }
            }
            .store(in: &cancellables)
    }

    private func bindDisplayState() {
        $state
            .combineLatest($favoriteIDs)
            .map { state, ids in SearchState(phase: Self.applyingFavorites(state.phase, favoriteIDs: ids)) }
            .assign(to: &$displayState)
    }

    private func observeFavorites() {
        // ループの外で self を強く握らない。握ると、画面が消えても購読が生き続けて
        // ViewModel が解放されなくなる（`deinit` で止められないので、ここで終わらせる）。
        favoriteTask = Task { [weak self] in
            guard let useCase = self?.observeFavoriteIDs else { return }
            let stream = await useCase()
            for await ids in stream {
                guard let self else { return }
                favoriteIDs = Set(ids.map(\.rawValue))
            }
        }
    }

    // MARK: - 検索

    private func startSearch(_ rawQuery: String) {
        searchTask?.cancel()
        loadMoreTask?.cancel()
        loadMoreTask = nil
        generation += 1
        let token = generation
        currentQuery = rawQuery

        guard SearchQuery(rawQuery) != nil else {
            state = SearchState(phase: .initial)
            return
        }

        state = SearchState(phase: .loading)
        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await searchRepos(rawQuery: rawQuery)
                guard token == generation else { return }
                guard let page else {
                    state = SearchState(phase: .initial)
                    return
                }
                apply(page: page, query: rawQuery)
            } catch {
                // キャンセルは失敗ではない。状態を変えない（AC-18）
                guard !GitHubErrorPresenter.isCancellation(error) else { return }
                guard token == generation else { return }
                state = SearchState(phase: .failed(GitHubErrorPresenter.errorState(for: error, now: now())))
            }
        }
    }

    private func loadMore() {
        guard case .loaded(let rows, let isLoadingMore) = state.phase else { return }
        guard !isLoadingMore, hasMore, loadMoreTask == nil else { return }

        let token = generation
        let page = nextPage
        let loaded = loadedCount
        let rawQuery = currentQuery
        state = SearchState(phase: .loaded(rows: rows, isLoadingMore: true))

        loadMoreTask = Task { [weak self] in
            guard let self else { return }
            defer { loadMoreTask = nil }
            do {
                let result = try await loadMoreRepos(
                    rawQuery: rawQuery,
                    nextPage: page,
                    loadedCount: loaded,
                    hasMore: true
                )
                // 検索語が変わっていたら、このページは捨てる（AC-28）
                guard token == generation else { return }
                guard let result else {
                    state = SearchState(phase: .loaded(rows: rows, isLoadingMore: false))
                    return
                }
                append(page: result)
            } catch {
                guard !GitHubErrorPresenter.isCancellation(error) else { return }
                guard token == generation else { return }
                // 一覧は消さない。通知だけ出す（BR-006・AC-27）
                state = SearchState(phase: .loaded(rows: rows, isLoadingMore: false))
                toast = GitHubErrorPresenter.errorState(for: error, now: now()).title
            }
        }
    }

    private func apply(page: RepoPage, query: String) {
        cache(page.items)
        orderedSummaries = page.items
        loadedCount = page.items.count
        nextPage = 2
        hasMore = page.hasMore
        guard !page.items.isEmpty else {
            state = SearchState(phase: .empty(query: query))
            return
        }
        state = SearchState(phase: .loaded(rows: rows(from: orderedSummaries), isLoadingMore: false))
    }

    /// 置き換えではなく**追記**する（AC-22）。
    private func append(page: RepoPage) {
        cache(page.items)
        orderedSummaries.append(contentsOf: page.items)
        loadedCount = orderedSummaries.count
        nextPage = page.page + 1
        hasMore = page.hasMore
        state = SearchState(phase: .loaded(rows: rows(from: orderedSummaries), isLoadingMore: false))
    }

    private func cache(_ items: [RepoSummary]) {
        for item in items {
            summaries[item.id.rawValue] = item
        }
    }

    private func rows(from items: [RepoSummary]) -> [SearchRow] {
        let triggerIndex = max(items.count - 3, 0)
        let timestamp = now()
        return items.enumerated().map { index, summary in
            SearchRow(
                display: RepoDisplayMapper.display(for: summary, isFavorite: false, now: timestamp),
                isLoadMoreTrigger: index >= triggerIndex
            )
        }
    }

    /// 派生状態の合成。純粋関数なので、`State` にロジックを置かずに済む。
    ///
    /// `nonisolated` なのは、Combine の `map` が MainActor の外で走るためである。
    nonisolated static func applyingFavorites(_ phase: SearchPhase, favoriteIDs: Set<Int>) -> SearchPhase {
        switch phase {
        case .loaded(let rows, let isLoadingMore):
            let updated = rows.map { row in
                SearchRow(
                    display: row.display.withFavorite(favoriteIDs.contains(row.display.id)),
                    isLoadMoreTrigger: row.isLoadMoreTrigger
                )
            }
            return .loaded(rows: updated, isLoadingMore: isLoadingMore)
        case .initial, .loading, .empty, .failed:
            return phase
        }
    }
}
