import Domain
import Testing
import TestSupport
import UseCase

@Suite("UC-002 UseCase: 詳細")
struct FetchRepoDetailUseCaseTests {
    @Test("owner と name をそのまま Repository へ渡す")
    func passesOwnerAndName() async throws {
        let repository = StubRepoRepository()
        await repository.setDetailResult(.success(.stub()))
        let useCase = FetchRepoDetailUseCase(repository: repository)

        _ = try await useCase(owner: "apple", name: "swift")

        let calls = await repository.detailCalls
        #expect(calls == ["apple/swift"])
    }

    @Test("Repository の失敗はそのまま伝わる")
    func propagatesError() async throws {
        let repository = StubRepoRepository()
        await repository.setDetailResult(.failure(GitHubError.notFound))
        let useCase = FetchRepoDetailUseCase(repository: repository)

        await #expect(throws: GitHubError.notFound) {
            _ = try await useCase(owner: "apple", name: "missing")
        }
    }
}
