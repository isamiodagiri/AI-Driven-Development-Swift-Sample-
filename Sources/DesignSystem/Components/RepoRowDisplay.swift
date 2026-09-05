import Foundation

/// 一覧の1行に出す値であり、**画面遷移に乗せる値**でもある。
///
/// DesignSystem に置いてあるのは、検索とお気に入りの2つの Feature が同じ行を描くためである
/// （Feature 同士は参照できない ＝ INV-2）。`Hashable` なのは遷移の経路に乗せるため。
///
/// 整形済みの文字列（`starsText` 等）と、**素の値**（`stars` 等）の両方を持つ。
/// 素の値が要るのは、詳細の取得に失敗した状態でもお気に入りに保存できるようにするためである
/// （UC-002 AC-20・AC-21）。持たせないと、保存した件数が 0 になってしまう。
public struct RepoRowDisplay: Sendable, Equatable, Hashable, Identifiable {
    public let id: Int
    public let ownerLogin: String
    public let name: String
    public let fullName: String
    public let avatarURL: URL?
    public let htmlURL: URL?
    public let description: String?
    public let stars: Int
    public let forks: Int
    public let starsText: String
    public let forksText: String
    public let language: String?
    public let updatedAt: Date?
    public let updatedText: String
    public let isFavorite: Bool

    public init(
        id: Int,
        ownerLogin: String,
        name: String,
        fullName: String,
        avatarURL: URL?,
        htmlURL: URL?,
        description: String?,
        stars: Int,
        forks: Int,
        starsText: String,
        forksText: String,
        language: String?,
        updatedAt: Date?,
        updatedText: String,
        isFavorite: Bool
    ) {
        self.id = id
        self.ownerLogin = ownerLogin
        self.name = name
        self.fullName = fullName
        self.avatarURL = avatarURL
        self.htmlURL = htmlURL
        self.description = description
        self.stars = stars
        self.forks = forks
        self.starsText = starsText
        self.forksText = forksText
        self.language = language
        self.updatedAt = updatedAt
        self.updatedText = updatedText
        self.isFavorite = isFavorite
    }

    public func withFavorite(_ isFavorite: Bool) -> RepoRowDisplay {
        RepoRowDisplay(
            id: id,
            ownerLogin: ownerLogin,
            name: name,
            fullName: fullName,
            avatarURL: avatarURL,
            htmlURL: htmlURL,
            description: description,
            stars: stars,
            forks: forks,
            starsText: starsText,
            forksText: forksText,
            language: language,
            updatedAt: updatedAt,
            updatedText: updatedText,
            isFavorite: isFavorite
        )
    }
}
