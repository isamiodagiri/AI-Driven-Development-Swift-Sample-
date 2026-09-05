/// GitHub のリポジトリ ID。素の `Int` を持ち回すと、スター数などと取り違える。
public struct RepoID: Sendable, Hashable {
    public let rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
}
