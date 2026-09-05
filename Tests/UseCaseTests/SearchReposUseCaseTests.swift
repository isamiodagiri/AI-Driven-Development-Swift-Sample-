import Domain
import Foundation
import Testing
import TestSupport
import UseCase

/// UC-001 の UseCase 層（TS-19〜TS-24）。
@Suite("UC-001 UseCase: 検索とページング")
struct SearchReposUseCaseTests {
    @Test("TS-19 空文字では Repository を呼ばない")
    func doesNotCallRepositoryForEmptyQuery() async throws {
        let repository = StubRepoRepository()
        let useCase = SearchReposUseCase(repository: repository)

        let page = try await useCase(rawQuery: "")

        #expect(page == nil)
        let calls = await repository.searchCalls
        #expect(calls.isEmpty)
    }

    @Test("TS-20 空白だけでは呼ばない")
    func doesNotCallRepositoryForWhitespaceQuery() async throws {
        let repository = StubRepoRepository()
        let useCase = SearchReposUseCase(repository: repository)

        let page = try await useCase(rawQuery: "   \n ")

        #expect(page == nil)
        let calls = await repository.searchCalls
        #expect(calls.isEmpty)
    }

    @Test("TS-21 前後の空白を取り除いた語で呼ぶ")
    func trimsQuery() async throws {
        let repository = StubRepoRepository()
        await repository.setSearchResult(.success(.stub()))
        let useCase = SearchReposUseCase(repository: repository)

        _ = try await useCase(rawQuery: "  swift  ")

        let calls = await repository.searchCalls
        #expect(calls == [StubRepoRepository.SearchCall(query: "swift", page: 1)])
    }

    @Test("1ページ目を要求する")
    func requestsFirstPage() async throws {
        let repository = StubRepoRepository()
        await repository.setSearchResult(.success(.stub()))
        let useCase = SearchReposUseCase(repository: repository)

        _ = try await useCase(rawQuery: "swift")

        let calls = await repository.searchCalls
        #expect(calls.first?.page == 1)
    }

    @Test("TS-22 取得済みが 1000 件なら次を呼ばない")
    func stopsAtSearchResultLimit() async throws {
        let repository = StubRepoRepository()
        await repository.setSearchResult(.success(.stub()))
        let useCase = LoadMoreReposUseCase(repository: repository)

        let page = try await useCase(rawQuery: "swift", nextPage: 34, loadedCount: 1000, hasMore: true)

        #expect(page == nil)
        let calls = await repository.searchCalls
        #expect(calls.isEmpty)
    }

    @Test("TS-23 hasMore が false なら呼ばない")
    func stopsWhenNoMore() async throws {
        let repository = StubRepoRepository()
        await repository.setSearchResult(.success(.stub()))
        let useCase = LoadMoreReposUseCase(repository: repository)

        let page = try await useCase(rawQuery: "swift", nextPage: 2, loadedCount: 30, hasMore: false)

        #expect(page == nil)
        let calls = await repository.searchCalls
        #expect(calls.isEmpty)
    }

    @Test("TS-24 渡された次のページ番号で呼ぶ")
    func requestsGivenNextPage() async throws {
        let repository = StubRepoRepository()
        await repository.setSearchResult(.success(.stub(count: 30, page: 2)))
        let useCase = LoadMoreReposUseCase(repository: repository)

        let page = try await useCase(rawQuery: "swift", nextPage: 2, loadedCount: 30, hasMore: true)

        #expect(page?.page == 2)
        let calls = await repository.searchCalls
        #expect(calls == [StubRepoRepository.SearchCall(query: "swift", page: 2)])
    }

    @Test("空の検索語では、次ページも呼ばない")
    func loadMoreRejectsEmptyQuery() async throws {
        let repository = StubRepoRepository()
        let useCase = LoadMoreReposUseCase(repository: repository)

        let page = try await useCase(rawQuery: " ", nextPage: 2, loadedCount: 30, hasMore: true)

        #expect(page == nil)
        let calls = await repository.searchCalls
        #expect(calls.isEmpty)
    }
}
