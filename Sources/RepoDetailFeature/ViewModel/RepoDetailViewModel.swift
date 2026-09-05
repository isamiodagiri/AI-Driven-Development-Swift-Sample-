import Combine
import Core
import DesignSystem
import Domain
import Foundation
import Presentation
import UseCase

/// 詳細画面。
///
/// **一覧から来たときは API を待たずに描き始め**（BR-007）、
/// **取得に失敗しても見出しは消さない**（BR-008）。未認証は 60 req/時しかないので、
/// 失敗しても白い画面にしないことが要る。
@MainActor
public final class RepoDetailViewModel: ObservableObject {
    @Published public private(set) var state: RepoDetailState
    @Published public private(set) var isFavorite = false
    @Published public var toast: String?

    private let ownerLogin: String
    private let repoName: String
    private let initialDisplay: RepoRowDisplay?
    private let fetchRepoDetail: FetchRepoDetailUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private let observeFavoriteIDs: ObserveFavoriteIDsUseCase
    private let now: @Sendable () -> Date

    private var fetchTask: Task<Void, Never>?
    private var favoriteTask: Task<Void, Never>?
    private var summary: RepoSummary?
    private var isStarted = false

    public init(
        ownerLogin: String,
        repoName: String,
        initialDisplay: RepoRowDisplay?,
        fetchRepoDetail: FetchRepoDetailUseCase,
        toggleFavorite: ToggleFavoriteUseCase,
        observeFavoriteIDs: ObserveFavoriteIDsUseCase,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.ownerLogin = ownerLogin
        self.repoName = repoName
        self.initialDisplay = initialDisplay
        self.fetchRepoDetail = fetchRepoDetail
        toggleFavoriteUseCase = toggleFavorite
        self.observeFavoriteIDs = observeFavoriteIDs
        self.now = now

        // 一覧が持っていた情報があるなら、取得を待たずにここで描ける状態にする（AC-1）。
        if let initialDisplay {
            state = RepoDetailState(
                phase: .partial(
                    header: RepoDetailHeader(display: initialDisplay, isArchived: false, isFork: false),
                    stats: RepoDetailStats(
                        starsText: initialDisplay.starsText,
                        forksText: initialDisplay.forksText,
                        watchersText: nil,
                        openIssuesText: nil
                    ),
                    error: nil
                )
            )
        } else {
            state = RepoDetailState(phase: .loading)
        }
    }

    public func onAppear() {
        guard !isStarted else { return }
        isStarted = true
        observeFavorites()
        fetch()
    }

    public func onDisappear() {
        // 画面を閉じたら取得は要らない（AC-15）。届いても状態は書かない（AC-16）。
        fetchTask?.cancel()
        fetchTask = nil
        favoriteTask?.cancel()
        favoriteTask = nil
    }

    public func retry() {
        fetch()
    }

    public func toggleFavorite() {
        // 詳細の取得に失敗していても、要約さえあれば付け外しはできる（AC-20・AC-21）
        guard let target = summary ?? summaryFromInitialDisplay() else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await toggleFavoriteUseCase(summary: target)
            } catch {
                toast = "お気に入りを保存できませんでした"
            }
        }
    }

    // MARK: - 内部

    private func fetch() {
        // 連打しても同時に走るのは1つだけ（AC-17）
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }
            // ここで fetchTask を nil に戻さない。連打したとき、古い Task の後始末が
            // 新しい Task の参照まで消してしまい、閉じたときに止められなくなる。
            do {
                let detail = try await fetchRepoDetail(owner: ownerLogin, name: repoName)
                guard !Task.isCancelled else { return }
                apply(detail)
            } catch {
                guard !GitHubErrorPresenter.isCancellation(error), !Task.isCancelled else { return }
                applyFailure(GitHubErrorPresenter.errorState(for: error, now: now()))
            }
        }
    }

    private func apply(_ detail: RepoDetail) {
        summary = detail.summary
        let display = RepoDisplayMapper.display(for: detail.summary, isFavorite: isFavorite, now: now())
        var fields: [RepoDetailField] = []
        if let language = detail.summary.language {
            fields.append(RepoDetailField(id: "language", label: "言語", value: language))
        }
        // ライセンスが無いときも行は残す（AC-4）
        fields.append(RepoDetailField(id: "license", label: "ライセンス", value: detail.licenseName ?? "なし"))
        fields.append(
            RepoDetailField(
                id: "updated",
                label: "更新",
                value: RelativeDateText.text(for: detail.summary.updatedAt, now: now())
            )
        )

        state = RepoDetailState(
            phase: .loaded(
                header: RepoDetailHeader(
                    display: display,
                    isArchived: detail.isArchived,
                    isFork: detail.isFork
                ),
                stats: RepoDetailStats(
                    starsText: CountText.compact(detail.summary.stars),
                    forksText: CountText.compact(detail.summary.forks),
                    watchersText: CountText.compact(detail.watchers),
                    openIssuesText: CountText.compact(detail.openIssues)
                ),
                fields: fields,
                topics: detail.topics
            ),
            htmlURL: detail.summary.htmlURL
        )
    }

    /// 見出しがあるなら残したまま部分的な失敗にする。無いなら画面全体を失敗にする（BR-008・AC-9・AC-10）。
    private func applyFailure(_ error: AppErrorState) {
        switch state.phase {
        case .partial(let header, let stats, _):
            state = RepoDetailState(phase: .partial(header: header, stats: stats, error: error), htmlURL: state.htmlURL)
        case .loaded(let header, let stats, _, _):
            state = RepoDetailState(phase: .partial(header: header, stats: stats, error: error), htmlURL: state.htmlURL)
        case .loading, .failed:
            state = RepoDetailState(phase: .failed(error))
        }
    }

    private func observeFavorites() {
        // ループの外で self を強く握らない（検索画面と同じ理由）。
        favoriteTask = Task { [weak self] in
            guard let useCase = self?.observeFavoriteIDs else { return }
            let stream = await useCase()
            for await ids in stream {
                guard let self else { return }
                let identifiers = Set(ids.map(\.rawValue))
                if let id = currentRepoID {
                    isFavorite = identifiers.contains(id)
                }
            }
        }
    }

    private var currentRepoID: Int? {
        summary?.id.rawValue ?? initialDisplay?.id
    }

    /// 一覧から来たときは、要約を組み立て直せる（詳細の取得を待たずに ★ を押せる）。
    private func summaryFromInitialDisplay() -> RepoSummary? {
        initialDisplay.map { RepoDisplayMapper.summary(from: $0) }
    }
}
