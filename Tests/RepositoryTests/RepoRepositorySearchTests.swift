import Core
import Domain
import Foundation
import Testing
import TestSupport

@testable import Repository

/// UC-001 の Repository 層（TS-1〜TS-18）。
@Suite("UC-001 Repository: 検索")
struct RepoRepositorySearchTests {
    private func makeQuery(_ text: String = "swift") throws -> SearchQuery {
        try #require(SearchQuery(text))
    }

    @Test("TS-1 正常応答 → 30件の RepoSummary になる")
    func decodesSearchResult() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("search_repositories_ok")))
        let repository = RepoRepositoryImpl(client: client)

        let page = try await repository.search(query: makeQuery(), page: 1)

        #expect(page.items.count == 30)
        #expect(page.totalCount == 4321)
        #expect(page.items.first?.fullName == "owner-1/repo-1")
        #expect(page.items.first?.stars == 66999)
        #expect(page.items.first?.owner.login == "owner-1")
    }

    @Test("TS-2 description が null → Entity では nil")
    func decodesNullDescription() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("search_repositories_null_fields")))
        let repository = RepoRepositoryImpl(client: client)

        let page = try await repository.search(query: makeQuery(), page: 1)

        #expect(page.items[0].description != nil)
        #expect(page.items[1].description == nil)
    }

    @Test("TS-3 language が null → Entity では nil")
    func decodesNullLanguage() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("search_repositories_null_fields")))
        let repository = RepoRepositoryImpl(client: client)

        let page = try await repository.search(query: makeQuery(), page: 1)

        #expect(page.items[1].language == nil)
    }

    @Test("TS-4 送るのは q / per_page=30 / page のみ。sort と order を含まない")
    func sendsOnlyExpectedQueryItems() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("search_repositories_ok")))
        let repository = RepoRepositoryImpl(client: client)

        _ = try await repository.search(query: makeQuery("swiftui"), page: 3)

        let request = try #require(await client.requests.first)
        #expect(request.queryItems == [
            QueryItem(name: "q", value: "swiftui"),
            QueryItem(name: "per_page", value: "30"),
            QueryItem(name: "page", value: "3"),
        ])
        #expect(request.url.path().hasSuffix("/search/repositories"))
    }

    @Test("TS-5 Accept / X-GitHub-Api-Version / User-Agent が付く")
    func sendsRequiredHeaders() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("search_repositories_ok")))
        let repository = RepoRepositoryImpl(client: client)

        _ = try await repository.search(query: makeQuery(), page: 1)

        let request = try #require(await client.requests.first)
        #expect(request.headers["Accept"] == "application/vnd.github+json")
        #expect(request.headers["X-GitHub-Api-Version"] == "2022-11-28")
        #expect(request.headers["User-Agent"] != nil)
        // トークンが無いときは Authorization ヘッダごと付けない（空だと 401 になる）
        #expect(request.headers["Authorization"] == nil)
    }

    @Test("トークンがあれば Authorization を付ける")
    func sendsAuthorizationWhenTokenExists() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("search_repositories_ok")))
        let repository = RepoRepositoryImpl(client: client, token: "token123")

        _ = try await repository.search(query: makeQuery(), page: 1)

        let request = try #require(await client.requests.first)
        #expect(request.headers["Authorization"] == "Bearer token123")
    }

    @Test("TS-6 30件ちょうど かつ total_count が大きい → hasMore true")
    func hasMoreWhenFullPage() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("search_repositories_ok")))
        let repository = RepoRepositoryImpl(client: client)

        let page = try await repository.search(query: makeQuery(), page: 1)

        #expect(page.hasMore)
    }

    @Test("TS-7 30件未満 → hasMore false")
    func noMoreWhenPartialPage() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("search_repositories_last_page")))
        let repository = RepoRepositoryImpl(client: client)

        let page = try await repository.search(query: makeQuery(), page: 1)

        #expect(!page.hasMore)
    }

    @Test("TS-8 取得済みが 1000 に達したら hasMore false（total_count が大きくても）")
    func noMoreWhenReachingSearchLimit() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("search_repositories_ok")))
        let repository = RepoRepositoryImpl(client: client)

        // 34 ページ目まで取ると 1020 件になり、Search API の上限 1000 を超える
        let page = try await repository.search(query: makeQuery(), page: 34)

        #expect(!page.hasMore)
    }

    @Test("TS-9 403 かつ x-ratelimit-remaining: 0 → rateLimited(resetAt:)")
    func mapsRateLimitedWithReset() async throws {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response(
            "error_403_rate_limit",
            statusCode: 403,
            headers: ["x-ratelimit-remaining": "0", "x-ratelimit-reset": "1800000000"]
        )))
        let repository = RepoRepositoryImpl(client: client)

        await #expect(throws: GitHubError.rateLimited(resetAt: reset)) {
            _ = try await repository.search(query: makeQuery(), page: 1)
        }
    }

    @Test("TS-10 x-ratelimit-reset が無い → rateLimited(resetAt: nil)")
    func mapsRateLimitedWithoutReset() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response(
            "error_403_rate_limit",
            statusCode: 403,
            headers: ["x-ratelimit-remaining": "0"]
        )))
        let repository = RepoRepositoryImpl(client: client)

        await #expect(throws: GitHubError.rateLimited(resetAt: nil)) {
            _ = try await repository.search(query: makeQuery(), page: 1)
        }
    }

    @Test("TS-11 429 かつ remaining 0 → rateLimited")
    func mapsTooManyRequests() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.emptyResponse(
            statusCode: 429,
            headers: ["x-ratelimit-remaining": "0"]
        )))
        let repository = RepoRepositoryImpl(client: client)

        await #expect(throws: GitHubError.rateLimited(resetAt: nil)) {
            _ = try await repository.search(query: makeQuery(), page: 1)
        }
    }

    @Test("retry-after があれば reset より優先する")
    func prefersRetryAfterOverReset() async throws {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.emptyResponse(
            statusCode: 403,
            headers: ["x-ratelimit-remaining": "0", "x-ratelimit-reset": "1800000000", "retry-after": "60"]
        )))
        let repository = RepoRepositoryImpl(client: client, now: { now })

        await #expect(throws: GitHubError.rateLimited(resetAt: now.addingTimeInterval(60))) {
            _ = try await repository.search(query: makeQuery(), page: 1)
        }
    }

    @Test("remaining が 0 でない 403 は rateLimited にしない")
    func doesNotTreatOtherForbiddenAsRateLimited() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.emptyResponse(
            statusCode: 403,
            headers: ["x-ratelimit-remaining": "58"]
        )))
        let repository = RepoRepositoryImpl(client: client)

        await #expect(throws: GitHubError.unknown) {
            _ = try await repository.search(query: makeQuery(), page: 1)
        }
    }

    @Test("TS-12 422 → invalidQuery に errors[0].message が入る")
    func mapsValidationError() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("error_422_validation", statusCode: 422)))
        let repository = RepoRepositoryImpl(client: client)

        await #expect(throws: GitHubError.invalidQuery(reason: "検索条件が不正です")) {
            _ = try await repository.search(query: makeQuery(), page: 1)
        }
    }

    @Test("TS-13 404 → notFound")
    func mapsNotFound() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.response("error_404_not_found", statusCode: 404)))
        let repository = RepoRepositoryImpl(client: client)

        await #expect(throws: GitHubError.notFound) {
            _ = try await repository.search(query: makeQuery(), page: 1)
        }
    }

    @Test("TS-14 500 → server(status: 500)")
    func mapsServerError() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.success(Fixture.emptyResponse(statusCode: 500)))
        let repository = RepoRepositoryImpl(client: client)

        await #expect(throws: GitHubError.server(status: 500)) {
            _ = try await repository.search(query: makeQuery(), page: 1)
        }
    }

    @Test("TS-15 壊れた JSON → decoding（unknown にまとめない）")
    func mapsDecodingError() async throws {
        let client = StubHTTPClient()
        let broken = HTTPResponse(statusCode: 200, body: Data("{ not json".utf8))
        await client.setDefault(.success(broken))
        let repository = RepoRepositoryImpl(client: client)

        await #expect(throws: GitHubError.decoding) {
            _ = try await repository.search(query: makeQuery(), page: 1)
        }
    }

    @Test("TS-16 通信できない → offline")
    func mapsOffline() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.failure(URLError(.notConnectedToInternet)))
        let repository = RepoRepositoryImpl(client: client)

        await #expect(throws: GitHubError.offline) {
            _ = try await repository.search(query: makeQuery(), page: 1)
        }
    }

    @Test("TS-17 タイムアウト → timeout")
    func mapsTimeout() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.failure(URLError(.timedOut)))
        let repository = RepoRepositoryImpl(client: client)

        await #expect(throws: GitHubError.timeout) {
            _ = try await repository.search(query: makeQuery(), page: 1)
        }
    }

    @Test("TS-18 URLError.cancelled は写像せず、そのまま投げる")
    func doesNotMapCancellation() async throws {
        let client = StubHTTPClient()
        await client.setDefault(.failure(URLError(.cancelled)))
        let repository = RepoRepositoryImpl(client: client)

        do {
            _ = try await repository.search(query: makeQuery(), page: 1)
            Issue.record("投げられるはずである")
        } catch let error as URLError {
            #expect(error.code == .cancelled)
        } catch {
            Issue.record("URLError.cancelled のままであるべきだが \(error) だった")
        }
    }
}
