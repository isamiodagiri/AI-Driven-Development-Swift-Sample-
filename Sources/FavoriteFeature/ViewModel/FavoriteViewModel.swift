import DesignSystem
import Domain
import Foundation
import Presentation
import UseCase

/// お気に入り画面。
///
/// **API を1回も呼ばない**（保存してある要約をそのまま出す ＝ AC-21）。
/// 一覧の中身は Repository の購読から来るので、他の画面での付け外しが即座に反映される。
@MainActor
public final class FavoriteViewModel: ObservableObject {
    @Published public private(set) var state = FavoriteState()
    @Published public var toast: String?

    private let observeFavorites: ObserveFavoritesUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private let now: @Sendable () -> Date

    private var observeTask: Task<Void, Never>?
    private var summaries: [Int: RepoSummary] = [:]
    private var isStarted = false

    public init(
        observeFavorites: ObserveFavoritesUseCase,
        toggleFavorite: ToggleFavoriteUseCase,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.observeFavorites = observeFavorites
        toggleFavoriteUseCase = toggleFavorite
        self.now = now
    }

    public func onAppear() {
        guard !isStarted else { return }
        isStarted = true
        // ループの外で self を強く握らない（握ると ViewModel が解放されない）。
        observeTask = Task { [weak self] in
            guard let useCase = self?.observeFavorites else { return }
            let stream = await useCase()
            for await favorites in stream {
                guard let self else { return }
                apply(favorites)
            }
        }
    }

    public func remove(rowID: Int) {
        guard let summary = summaries[rowID] else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await toggleFavoriteUseCase(summary: summary)
            } catch {
                // 失敗したら表示は元に戻る（購読が真実源を流し直す ＝ BR-012）
                toast = "お気に入りを更新できませんでした"
            }
        }
    }

    private func apply(_ favorites: [FavoriteRepo]) {
        summaries = favorites.reduce(into: [:]) { result, favorite in
            result[favorite.id.rawValue] = favorite.summary
        }
        guard !favorites.isEmpty else {
            state = FavoriteState(phase: .empty)
            return
        }
        // 並び順は Repository が持つ（画面ごとに並べ替えるとタブ間でずれる ＝ BR-013）
        let timestamp = now()
        let rows = favorites.map { favorite in
            RepoDisplayMapper.display(for: favorite.summary, isFavorite: true, now: timestamp)
        }
        state = FavoriteState(phase: .loaded(rows: rows))
    }
}
