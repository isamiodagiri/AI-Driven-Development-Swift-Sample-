import DesignSystem
import Foundation

/// 詳細に出す1項目（ラベルと値の組）。
public struct RepoDetailField: Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let value: String

    public init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public struct RepoDetailStats: Sendable, Equatable {
    public let starsText: String
    public let forksText: String
    public let watchersText: String?
    public let openIssuesText: String?

    public init(starsText: String, forksText: String, watchersText: String?, openIssuesText: String?) {
        self.starsText = starsText
        self.forksText = forksText
        self.watchersText = watchersText
        self.openIssuesText = openIssuesText
    }
}

/// 見出し（一覧から来たときは API を待たずに埋まっている ＝ BR-007）。
public struct RepoDetailHeader: Sendable, Equatable {
    public let display: RepoRowDisplay
    public let isArchived: Bool
    public let isFork: Bool

    public init(display: RepoRowDisplay, isArchived: Bool, isFork: Bool) {
        self.display = display
        self.isArchived = isArchived
        self.isFork = isFork
    }
}

public enum RepoDetailPhase: Sendable, Equatable {
    /// 一覧の情報も無く、取得もまだ。
    case loading
    /// 見出しだけ描けている。詳細は取得中か、取得に失敗している。
    case partial(header: RepoDetailHeader, stats: RepoDetailStats, error: AppErrorState?)
    case loaded(header: RepoDetailHeader, stats: RepoDetailStats, fields: [RepoDetailField], topics: [String])
    /// 見出しも無く、取得にも失敗した。
    case failed(AppErrorState)
}

public struct RepoDetailState: Sendable, Equatable {
    public var phase: RepoDetailPhase
    public var htmlURL: URL?

    public init(phase: RepoDetailPhase = .loading, htmlURL: URL? = nil) {
        self.phase = phase
        self.htmlURL = htmlURL
    }
}
