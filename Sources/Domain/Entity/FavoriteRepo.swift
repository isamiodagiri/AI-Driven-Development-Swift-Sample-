import Foundation

/// 端末に保存したお気に入り。**ID だけでなく要約ごと持つ**（BR-011）。
/// ID だけだと一覧を開くたびに N 件の詳細 API を叩き、未認証の 60 req/時を使い切る。
public struct FavoriteRepo: Sendable, Equatable, Identifiable {
    public let summary: RepoSummary
    public let addedAt: Date

    public var id: RepoID { summary.id }

    public init(summary: RepoSummary, addedAt: Date) {
        self.summary = summary
        self.addedAt = addedAt
    }
}
