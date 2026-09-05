import Core
import Domain
import Foundation

/// 保持しているのは `let` だけなので、`@unchecked` なしで `Sendable` である（INV-4）。
public struct RepoRepositoryImpl: RepoRepository {
    private let client: any HTTPClient
    private let token: String?
    private let now: @Sendable () -> Date

    public init(client: any HTTPClient, token: String? = nil, now: @escaping @Sendable () -> Date = { Date() }) {
        self.client = client
        self.token = token
        self.now = now
    }

    public func search(query: SearchQuery, page: Int) async throws -> RepoPage {
        // sort / order は送らない。best match が最も期待に近く、送らないことを AC-15 が固定している。
        let request = HTTPRequest(
            url: GitHubAPI.baseURL.appending(path: "search/repositories"),
            queryItems: [
                QueryItem(name: "q", value: query.rawValue),
                QueryItem(name: "per_page", value: String(GitHubAPI.perPage)),
                QueryItem(name: "page", value: String(page)),
            ],
            headers: GitHubAPI.headers(token: token)
        )

        let dto: RepoSearchResponseDTO = try await send(request)
        let items = dto.items.map { $0.toEntity() }
        return RepoPage(
            items: items,
            totalCount: dto.totalCount,
            page: page,
            hasMore: Self.hasMore(pageItemCount: items.count, page: page, totalCount: dto.totalCount)
        )
    }

    public func fetchDetail(owner: String, name: String) async throws -> RepoDetail {
        let request = HTTPRequest(
            url: GitHubAPI.baseURL.appending(path: "repos/\(owner)/\(name)"),
            headers: GitHubAPI.headers(token: token)
        )
        let dto: RepoDetailDTO = try await send(request)
        return dto.toEntity()
    }

    /// 「この応答から分かること」だけを決める。次を要求してよいかの判断は UseCase が持つ（BR-005）。
    static func hasMore(pageItemCount: Int, page: Int, totalCount: Int) -> Bool {
        guard pageItemCount == GitHubAPI.perPage else { return false }
        let loaded = page * GitHubAPI.perPage
        let reachable = min(totalCount, GitHubAPI.searchResultLimit)
        return loaded < reachable
    }

    private func send<T: Decodable>(_ request: HTTPRequest) async throws -> T {
        let response: HTTPResponse
        do {
            response = try await client.send(request)
        } catch {
            throw GitHubErrorMapper.error(from: error)
        }

        if let error = GitHubErrorMapper.error(from: response, now: now) {
            throw error
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(T.self, from: response.body)
        } catch {
            // decoding を unknown にまとめない。API の形が変わったと気づける唯一の信号である。
            AppLogger.error("応答の形が違う: \(error)")
            throw GitHubError.decoding
        }
    }
}
