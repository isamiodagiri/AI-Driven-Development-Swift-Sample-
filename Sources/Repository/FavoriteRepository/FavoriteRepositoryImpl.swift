import Core
import Domain
import Foundation

/// 可変状態を持つので `actor` にする（チェックを外した `Sendable` 準拠を書かないための選択 ＝ INV-4）。
public actor FavoriteRepositoryImpl: FavoriteRepository {
    private static let storageKey = "favorites.v1"

    private let store: any KeyValueStore
    private let now: @Sendable () -> Date
    private var items: [FavoriteRepo] = []
    private var continuations: [UUID: AsyncStream<[FavoriteRepo]>.Continuation] = [:]
    private var isLoaded = false

    public init(store: any KeyValueStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    public func favorites() async -> [FavoriteRepo] {
        await loadIfNeeded()
        return items
    }

    public func stream() async -> AsyncStream<[FavoriteRepo]> {
        await loadIfNeeded()
        let id = UUID()
        let (stream, continuation) = AsyncStream<[FavoriteRepo]>.makeStream()
        continuation.yield(items)
        continuations[id] = continuation
        // 捨て忘れると、画面を開くたびに購読が積み上がる（画面は消えているのに通知だけ増える）。
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    public func add(_ summary: RepoSummary) async throws {
        await loadIfNeeded()
        guard !items.contains(where: { $0.id == summary.id }) else { return }
        var next = items
        next.append(FavoriteRepo(summary: summary, addedAt: now()))
        try await commit(Self.sorted(next))
    }

    public func remove(id: RepoID) async throws {
        await loadIfNeeded()
        guard items.contains(where: { $0.id == id }) else { return }
        try await commit(items.filter { $0.id != id })
    }

    /// テストが「購読が捨てられたか」を観測するための口。
    public func activeSubscriptionCount() -> Int {
        continuations.count
    }

    // MARK: - 内部

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    /// **保存に成功してから**内部の状態を差し替える。
    /// 先に差し替えると、失敗したのに画面だけ変わった状態になる（BR-012）。
    private func commit(_ next: [FavoriteRepo]) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(next.map { FavoriteRepoDTO($0) })
        try await store.set(data, forKey: Self.storageKey)
        items = next
        for continuation in continuations.values {
            continuation.yield(next)
        }
    }

    private func loadIfNeeded() async {
        guard !isLoaded else { return }
        isLoaded = true
        guard let data = await store.data(forKey: Self.storageKey) else { return }
        let decoder = JSONDecoder()
        guard let dtos = try? decoder.decode([FavoriteRepoDTO].self, from: data) else {
            // 壊れた保存データで落とさない。空として扱う（AC-15）。
            AppLogger.error("お気に入りの保存データを読めなかった。空として扱う")
            return
        }
        items = Self.sorted(dtos.map { $0.toEntity() })
    }

    /// 並び順は保存側が持つ（画面ごとに並べ替えるとタブ間でずれる ＝ BR-013）。
    private static func sorted(_ items: [FavoriteRepo]) -> [FavoriteRepo] {
        items.sorted { $0.addedAt > $1.addedAt }
    }
}
