import Foundation

/// 一覧に出すぶんのリポジトリ情報。
///
/// 名前が `Repo*` なのは、層としての Repository と語がぶつかるため（裁定 D-2）。
public struct RepoSummary: Sendable, Equatable, Identifiable {
    public let id: RepoID
    public let name: String
    public let fullName: String
    public let owner: Owner
    public let description: String?
    public let htmlURL: URL?
    public let stars: Int
    public let forks: Int
    public let language: String?
    public let updatedAt: Date?

    public init(
        id: RepoID,
        name: String,
        fullName: String,
        owner: Owner,
        description: String?,
        htmlURL: URL?,
        stars: Int,
        forks: Int,
        language: String?,
        updatedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.owner = owner
        self.description = description
        self.htmlURL = htmlURL
        self.stars = stars
        self.forks = forks
        self.language = language
        self.updatedAt = updatedAt
    }
}
