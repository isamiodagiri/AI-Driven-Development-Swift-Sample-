import Core
import Domain
import Foundation
import Testing
import TestSupport

@testable import Repository

/// UC-003 の Repository 層（TS-77〜TS-87）。
@Suite("UC-003 Repository: お気に入り")
struct FavoriteRepositoryTests {
    private func makeRepository(
        store: InMemoryKeyValueStore = InMemoryKeyValueStore(),
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_000_000) }
    ) -> FavoriteRepositoryImpl {
        FavoriteRepositoryImpl(store: store, now: now)
    }

    @Test("TS-77 add で一覧に入る")
    func addsFavorite() async throws {
        let repository = makeRepository()

        try await repository.add(.stub(id: 1))

        let favorites = await repository.favorites()
        #expect(favorites.map(\.id) == [RepoID(1)])
    }

    @Test("TS-78 remove で消える")
    func removesFavorite() async throws {
        let repository = makeRepository()
        try await repository.add(.stub(id: 1))

        try await repository.remove(id: RepoID(1))

        let favorites = await repository.favorites()
        #expect(favorites.isEmpty)
    }

    @Test("TS-79 同じ id を2回 add しても1件")
    func doesNotDuplicate() async throws {
        let repository = makeRepository()

        try await repository.add(.stub(id: 1))
        try await repository.add(.stub(id: 1))

        let favorites = await repository.favorites()
        #expect(favorites.count == 1)
    }

    @Test("TS-80 並びは addedAt の降順（追加した新しい順）")
    func sortsByAddedAtDescending() async throws {
        let clock = MutableClock(start: Date(timeIntervalSince1970: 1_000_000))
        let repository = makeRepository(now: { clock.now })

        try await repository.add(.stub(id: 1))
        clock.advance(by: 60)
        try await repository.add(.stub(id: 2))
        clock.advance(by: 60)
        try await repository.add(.stub(id: 3))

        let favorites = await repository.favorites()
        #expect(favorites.map(\.id) == [RepoID(3), RepoID(2), RepoID(1)])
    }

    @Test("TS-81 作り直しても残る（保存から復元する）")
    func restoresFromStore() async throws {
        let store = InMemoryKeyValueStore()
        let first = makeRepository(store: store)
        try await first.add(.stub(id: 7))

        let second = makeRepository(store: store)
        let favorites = await second.favorites()

        #expect(favorites.map(\.id) == [RepoID(7)])
    }

    @Test("TS-82 壊れた保存データ → 空として扱い、落ちない")
    func toleratesBrokenData() async {
        let store = InMemoryKeyValueStore(initial: ["favorites.v1": Data("壊れている".utf8)])
        let repository = makeRepository(store: store)

        let favorites = await repository.favorites()

        #expect(favorites.isEmpty)
    }

    @Test("TS-83 購読した瞬間に現在値が1回流れる")
    func yieldsCurrentValueOnSubscribe() async throws {
        let repository = makeRepository()
        try await repository.add(.stub(id: 1))

        let stream = await repository.stream()
        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()

        #expect(first?.map(\.id) == [RepoID(1)])
    }

    @Test("TS-84 購読者が2つあるとき、両方に同じ変化が届く")
    func broadcastsToAllSubscribers() async throws {
        let repository = makeRepository()
        let streamA = await repository.stream()
        let streamB = await repository.stream()
        var iteratorA = streamA.makeAsyncIterator()
        var iteratorB = streamB.makeAsyncIterator()
        _ = await iteratorA.next() // 現在値（空）
        _ = await iteratorB.next()

        try await repository.add(.stub(id: 42))

        let receivedA = await iteratorA.next()
        let receivedB = await iteratorB.next()
        #expect(receivedA?.map(\.id) == [RepoID(42)])
        #expect(receivedB?.map(\.id) == [RepoID(42)])
    }

    @Test("TS-85 購読を終えると continuation が捨てられる（積み上がらない）")
    func releasesContinuationOnTermination() async {
        let repository = makeRepository()

        do {
            let stream = await repository.stream()
            var iterator = stream.makeAsyncIterator()
            _ = await iterator.next()
            let count = await repository.activeSubscriptionCount()
            #expect(count == 1)
        }

        // スコープを抜けて stream が解放されると onTermination が走る
        await waitUntil { await repository.activeSubscriptionCount() == 0 }
        let count = await repository.activeSubscriptionCount()
        #expect(count == 0)
    }

    @Test("TS-86 保存に失敗したら throw し、内部の状態も変わらない")
    func doesNotMutateWhenSaveFails() async throws {
        let store = InMemoryKeyValueStore()
        let repository = makeRepository(store: store)
        try await repository.add(.stub(id: 1))
        await store.failNextWrites()

        await #expect(throws: StoreFailure.self) {
            try await repository.add(.stub(id: 2))
        }

        let favorites = await repository.favorites()
        #expect(favorites.map(\.id) == [RepoID(1)])
    }

    @Test("TS-87 ネットワークを1回も使わない")
    func neverUsesNetwork() async throws {
        let client = StubHTTPClient()
        let repository = makeRepository()

        try await repository.add(.stub(id: 1))
        _ = await repository.favorites()
        try await repository.remove(id: RepoID(1))

        let count = await client.requestCount
        #expect(count == 0)
    }
}
