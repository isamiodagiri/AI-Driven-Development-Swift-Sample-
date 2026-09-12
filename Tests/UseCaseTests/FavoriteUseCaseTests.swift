import Domain
import Foundation
import Repository
import Testing
import TestSupport
import UseCase

/// UC-003 の UseCase 層（TS-88・TS-89）。
///
/// Repository は**実物**を使う（`FavoriteRepositoryImpl` ＋ 保存だけ差し替え）。
/// ダブルを重ねるほど、実物とずれる箇所が増えるためである（docs/04-test-strategy.md §4）。
@Suite("UC-003 UseCase: お気に入り")
struct FavoriteUseCaseTests {
    private func makeRepository() -> FavoriteRepositoryImpl {
        FavoriteRepositoryImpl(store: InMemoryKeyValueStore(), now: { Date(timeIntervalSince1970: 1_000_000) })
    }

    @Test("TS-88 未登録なら追加し、登録済みなら外す")
    func togglesBothWays() async throws {
        let repository = makeRepository()
        let toggle = ToggleFavoriteUseCase(repository: repository)

        let added = try await toggle(summary: .stub(id: 1))
        #expect(added)
        var favorites = await repository.favorites()
        #expect(favorites.count == 1)

        let removed = try await toggle(summary: .stub(id: 1))
        #expect(!removed)
        favorites = await repository.favorites()
        #expect(favorites.isEmpty)
    }

    @Test("TS-89 一覧は Repository の値をそのまま返し、API を呼ばない")
    func listDoesNotCallAPI() async throws {
        let client = StubHTTPClient()
        let repository = makeRepository()
        try await repository.add(.stub(id: 3))
        let list = ListFavoriteReposUseCase(repository: repository)

        let favorites = await list()

        #expect(favorites.map(\.id) == [RepoID(3)])
        let requestCount = await client.requestCount
        #expect(requestCount == 0)
    }

    @Test("TS-103 ID の購読を終えると、上流の購読も畳まれる", .timeLimit(.minutes(1)))
    func releasesUpstreamOnTermination() async {
        let repository = makeRepository()
        let observe = ObserveFavoriteIDsUseCase(repository: repository)

        do {
            let stream = await observe()
            var iterator = stream.makeAsyncIterator()
            _ = await iterator.next()
            let count = await repository.activeSubscriptionCount()
            #expect(count == 1)
        }

        // ここで畳めないと、画面を閉じるたびに購読が積み上がる。
        // TS-85 は Repository 側を見ており、**UseCase が挟まると別の話になる**
        await waitUntil { await repository.activeSubscriptionCount() == 0 }
        let count = await repository.activeSubscriptionCount()
        #expect(count == 0)
    }

    @Test("ID の購読は、変化のたびに ID の集合を流す", .timeLimit(.minutes(1)))
    func observesIdentifiers() async throws {
        let repository = makeRepository()
        let observe = ObserveFavoriteIDsUseCase(repository: repository)
        let stream = await observe()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        try await repository.add(.stub(id: 5))

        let ids = await iterator.next()
        #expect(ids == Set([RepoID(5)]))
    }
}
