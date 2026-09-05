import Domain
import Foundation

/// テストのための組み立て。**既定値は「ふつうの1件」**にして、
/// 各テストが「そのテストで意味のある値」だけを渡せるようにする。
extension RepoSummary {
    public static func stub(
        id: Int = 1,
        name: String = "swift",
        fullName: String = "apple/swift",
        ownerLogin: String = "apple",
        avatarURL: URL? = URL(string: "https://example.com/avatar.png"),
        description: String? = "The Swift Programming Language",
        htmlURL: URL? = URL(string: "https://github.com/apple/swift"),
        stars: Int = 67000,
        forks: Int = 10200,
        language: String? = "C++",
        updatedAt: Date? = Date(timeIntervalSince1970: 1_756_000_000)
    ) -> RepoSummary {
        RepoSummary(
            id: RepoID(id),
            name: name,
            fullName: fullName,
            owner: Owner(login: ownerLogin, avatarURL: avatarURL),
            description: description,
            htmlURL: htmlURL,
            stars: stars,
            forks: forks,
            language: language,
            updatedAt: updatedAt
        )
    }
}

extension RepoDetail {
    public static func stub(
        summary: RepoSummary = .stub(),
        watchers: Int = 1200,
        openIssues: Int = 340,
        licenseName: String? = "Apache License 2.0",
        topics: [String] = ["swift", "compiler"],
        homepageURL: URL? = nil,
        isArchived: Bool = false,
        isFork: Bool = false
    ) -> RepoDetail {
        RepoDetail(
            summary: summary,
            watchers: watchers,
            openIssues: openIssues,
            licenseName: licenseName,
            topics: topics,
            homepageURL: homepageURL,
            isArchived: isArchived,
            isFork: isFork
        )
    }
}

extension RepoPage {
    public static func stub(
        items: [RepoSummary] = [.stub()],
        totalCount: Int = 100,
        page: Int = 1,
        hasMore: Bool = false
    ) -> RepoPage {
        RepoPage(items: items, totalCount: totalCount, page: page, hasMore: hasMore)
    }

    /// `count` 件の連番のページ。
    public static func stub(count: Int, totalCount: Int = 1000, page: Int = 1, hasMore: Bool = true) -> RepoPage {
        let offset = (page - 1) * count
        let items = (0..<count).map { index in
            RepoSummary.stub(id: offset + index + 1, fullName: "owner/repo-\(offset + index + 1)")
        }
        return RepoPage(items: items, totalCount: totalCount, page: page, hasMore: hasMore)
    }
}
