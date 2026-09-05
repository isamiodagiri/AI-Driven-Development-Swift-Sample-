import Domain
import Foundation

/// 端末に保存する形。Domain の Entity を直接 `Codable` にしないのは、
/// 保存形式の都合（版番号・欄の追加）が Entity へ漏れないようにするため。
struct FavoriteRepoDTO: Codable {
    let id: Int
    let name: String
    let fullName: String
    let ownerLogin: String
    let avatarURL: URL?
    let description: String?
    let htmlURL: URL?
    let stars: Int
    let forks: Int
    let language: String?
    let updatedAt: Date?
    let addedAt: Date

    init(_ favorite: FavoriteRepo) {
        let summary = favorite.summary
        id = summary.id.rawValue
        name = summary.name
        fullName = summary.fullName
        ownerLogin = summary.owner.login
        avatarURL = summary.owner.avatarURL
        description = summary.description
        htmlURL = summary.htmlURL
        stars = summary.stars
        forks = summary.forks
        language = summary.language
        updatedAt = summary.updatedAt
        addedAt = favorite.addedAt
    }

    func toEntity() -> FavoriteRepo {
        FavoriteRepo(
            summary: RepoSummary(
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
            ),
            addedAt: addedAt
        )
    }
}
