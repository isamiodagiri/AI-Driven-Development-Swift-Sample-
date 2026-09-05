import Domain

/// お気に入りの真実源。**画面は自前のフラグを持たない**（BR-010）。
public protocol FavoriteRepository: Sendable {
    func favorites() async -> [FavoriteRepo]
    /// 変化の通知。購読した瞬間に現在値が1回流れる。複数の画面が同時に購読できる。
    func stream() async -> AsyncStream<[FavoriteRepo]>
    func add(_ summary: RepoSummary) async throws
    func remove(id: RepoID) async throws
}
