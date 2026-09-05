import Foundation

/// 端末内保存の口。
///
/// **`async` にしてあるのは、実装を `actor` にできるようにするため**である。
/// 同期の口にすると、テスト用の実装が「ロックを持ち、チェックを外して `Sendable` を名乗るクラス」になり、
/// INV-4 に違反する。**不変条件のほうが口の形を決めた**、という例である。
public protocol KeyValueStore: Sendable {
    func data(forKey key: String) async -> Data?
    func set(_ data: Data, forKey key: String) async throws
}

/// `UserDefaults` を触ってよい唯一の場所（INV-3）。
///
/// 保持しているのは suite 名（`String?`）だけで、`UserDefaults` 自体は都度取り出す。
/// こうすると、チェックを外した準拠を書かずに `Sendable` を満たせる。
public struct UserDefaultsKeyValueStore: KeyValueStore {
    private let suiteName: String?

    public init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        guard let suiteName, let suite = UserDefaults(suiteName: suiteName) else {
            return .standard
        }
        return suite
    }

    public func data(forKey key: String) async -> Data? {
        defaults.data(forKey: key)
    }

    public func set(_ data: Data, forKey key: String) async throws {
        defaults.set(data, forKey: key)
    }
}
