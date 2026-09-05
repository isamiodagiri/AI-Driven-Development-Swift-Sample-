import Domain
import Foundation

/// API の JSON に1対1で対応する型。**Repository の外へ出さない**。
struct OwnerDTO: Decodable {
    let login: String
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
    }
}

struct LicenseDTO: Decodable {
    let name: String?
}

struct RepoSummaryDTO: Decodable {
    let id: Int
    let name: String
    let fullName: String
    let owner: OwnerDTO
    let description: String?
    let htmlURL: URL?
    let stargazersCount: Int
    let forksCount: Int
    let language: String?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, owner, description, language
        case fullName = "full_name"
        case htmlURL = "html_url"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case updatedAt = "updated_at"
    }

    func toEntity() -> RepoSummary {
        RepoSummary(
            id: RepoID(id),
            name: name,
            fullName: fullName,
            owner: Owner(login: owner.login, avatarURL: owner.avatarURL),
            description: description,
            htmlURL: htmlURL,
            stars: stargazersCount,
            forks: forksCount,
            language: language,
            updatedAt: updatedAt
        )
    }
}

struct RepoSearchResponseDTO: Decodable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [RepoSummaryDTO]

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
    }
}

struct RepoDetailDTO: Decodable {
    let summary: RepoSummaryDTO
    /// 実際のウォッチャー数。検索結果の `watchers_count` は star と同値なので使わない（BR-009）。
    let subscribersCount: Int
    let openIssuesCount: Int
    let license: LicenseDTO?
    let topics: [String]?
    let homepage: String?
    let archived: Bool
    let fork: Bool

    enum CodingKeys: String, CodingKey {
        case license, topics, homepage, archived, fork
        case subscribersCount = "subscribers_count"
        case openIssuesCount = "open_issues_count"
    }

    init(from decoder: Decoder) throws {
        // 要約の項目は同じ階層に並んでいるので、そのままもう一度読む。
        summary = try RepoSummaryDTO(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subscribersCount = try container.decodeIfPresent(Int.self, forKey: .subscribersCount) ?? 0
        openIssuesCount = try container.decodeIfPresent(Int.self, forKey: .openIssuesCount) ?? 0
        license = try container.decodeIfPresent(LicenseDTO.self, forKey: .license)
        topics = try container.decodeIfPresent([String].self, forKey: .topics)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        fork = try container.decodeIfPresent(Bool.self, forKey: .fork) ?? false
    }

    func toEntity() -> RepoDetail {
        RepoDetail(
            summary: summary.toEntity(),
            watchers: subscribersCount,
            openIssues: openIssuesCount,
            licenseName: license?.name,
            topics: topics ?? [],
            homepageURL: homepage.flatMap { $0.isEmpty ? nil : URL(string: $0) },
            isArchived: archived,
            isFork: fork
        )
    }
}

/// 422 の本文。`errors[0].message` を利用者向けの理由に使う。
struct ValidationErrorDTO: Decodable {
    struct Item: Decodable {
        let message: String?
    }

    let message: String?
    let errors: [Item]?
}
