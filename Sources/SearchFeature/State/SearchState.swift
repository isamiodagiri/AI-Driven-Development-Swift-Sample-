import DesignSystem

/// 一覧の1行。**ロジックを持たない**（`isLoadMoreTrigger` の判定は ViewModel が済ませてある）。
public struct SearchRow: Sendable, Equatable, Identifiable {
    public let display: RepoRowDisplay
    /// 末尾から3行以内か。View に添え字の計算をさせないために、ここへ畳んである（AC-20）。
    public let isLoadMoreTrigger: Bool

    public var id: Int { display.id }

    public init(display: RepoRowDisplay, isLoadMoreTrigger: Bool) {
        self.display = display
        self.isLoadMoreTrigger = isLoadMoreTrigger
    }
}

/// 画面の状態。**排他な列挙**にしてあるので「読み込み中かつエラー」は表現できない。
public enum SearchPhase: Sendable, Equatable {
    case initial
    case loading
    case loaded(rows: [SearchRow], isLoadingMore: Bool)
    case empty(query: String)
    case failed(AppErrorState)
}

public struct SearchState: Sendable, Equatable {
    public var phase: SearchPhase

    public init(phase: SearchPhase = .initial) {
        self.phase = phase
    }
}
