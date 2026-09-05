/// 検索結果の1ページ。
///
/// `hasMore` は「この応答から分かること」であり、**次を要求してよいかの判断は UseCase**が持つ
/// （UC-001 §5。判断を2箇所に置かない）。
public struct RepoPage: Sendable, Equatable {
    public let items: [RepoSummary]
    public let totalCount: Int
    public let page: Int
    public let hasMore: Bool

    public init(items: [RepoSummary], totalCount: Int, page: Int, hasMore: Bool) {
        self.items = items
        self.totalCount = totalCount
        self.page = page
        self.hasMore = hasMore
    }
}
