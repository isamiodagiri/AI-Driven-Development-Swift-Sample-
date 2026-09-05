import Foundation

/// 詳細画面でだけ要る情報。一覧と重なる部分は `summary` が持つ（二重に持たない）。
public struct RepoDetail: Sendable, Equatable {
    public let summary: RepoSummary
    /// 実際のウォッチャー数。検索結果の `watchers_count` は star と同値なので使わない（BR-009）。
    public let watchers: Int
    public let openIssues: Int
    public let licenseName: String?
    public let topics: [String]
    public let homepageURL: URL?
    public let isArchived: Bool
    public let isFork: Bool

    public init(
        summary: RepoSummary,
        watchers: Int,
        openIssues: Int,
        licenseName: String?,
        topics: [String],
        homepageURL: URL?,
        isArchived: Bool,
        isFork: Bool
    ) {
        self.summary = summary
        self.watchers = watchers
        self.openIssues = openIssues
        self.licenseName = licenseName
        self.topics = topics
        self.homepageURL = homepageURL
        self.isArchived = isArchived
        self.isFork = isFork
    }
}
