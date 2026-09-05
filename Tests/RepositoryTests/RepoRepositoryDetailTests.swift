import Core
import Domain
import Foundation
import Testing
import TestSupport

@testable import Repository

/// UC-002 の Repository 層（TS-54〜TS-57）。
@Suite("UC-002 Repository: 詳細")
struct RepoRepositoryDetailTests {
    @Test("TS-54 詳細応答 → RepoDetail。watchers は subscribers_count である")
    func decodesDetail() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("repo_detail_ok")))
        let repository = RepoRepositoryImpl(client: client)

        let detail = try await repository.fetchDetail(owner: "owner-1", name: "repo-1")

        #expect(detail.summary.fullName == "owner-1/repo-1")
        // 検索結果の watchers_count（= star と同値）ではなく subscribers_count を使う（BR-009）
        #expect(detail.watchers == 1234)
        #expect(detail.summary.stars == 66999)
        #expect(detail.openIssues == 340)
        #expect(detail.licenseName == "Apache License 2.0")
        #expect(detail.topics == ["swift", "compiler"])
    }

    @Test("詳細の要求先は /repos/{owner}/{name} である")
    func requestsCorrectPath() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("repo_detail_ok")))
        let repository = RepoRepositoryImpl(client: client)

        _ = try await repository.fetchDetail(owner: "apple", name: "swift")

        let path = try #require(await client.requestedPaths().first)
        #expect(path.hasSuffix("/repos/apple/swift"))
    }

    @Test("TS-55 license が null → nil")
    func decodesNullLicense() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("repo_detail_no_license")))
        let repository = RepoRepositoryImpl(client: client)

        let detail = try await repository.fetchDetail(owner: "owner-2", name: "repo-2")

        #expect(detail.licenseName == nil)
    }

    @Test("TS-56 topics が空 → 空配列。archived / fork も読む")
    func decodesEmptyTopics() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("repo_detail_no_license")))
        let repository = RepoRepositoryImpl(client: client)

        let detail = try await repository.fetchDetail(owner: "owner-2", name: "repo-2")

        #expect(detail.topics.isEmpty)
        #expect(detail.isArchived)
        #expect(detail.isFork)
    }

    @Test("TS-57 404 → notFound")
    func mapsNotFound() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("error_404_not_found", statusCode: 404)))
        let repository = RepoRepositoryImpl(client: client)

        await #expect(throws: GitHubError.notFound) {
            _ = try await repository.fetchDetail(owner: "owner", name: "missing")
        }
    }
}
