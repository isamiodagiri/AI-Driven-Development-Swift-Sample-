import Foundation
import Repository

public struct StoreFailure: Error, Equatable {
    public init() {}
}

/// 端末内保存の差し替え。**書き込みを失敗させられる**（BR-012 / TS-86 のため）。
///
/// `actor` なのは、チェックを外した `Sendable` 準拠を書かないため（INV-4）。
/// これを可能にするために `KeyValueStore` の口が `async` になっている。
public actor InMemoryKeyValueStore: KeyValueStore {
    private var storage: [String: Data]
    private var shouldFailWrite = false

    public init(initial: [String: Data] = [:]) {
        storage = initial
    }

    public func failNextWrites(_ shouldFail: Bool = true) {
        shouldFailWrite = shouldFail
    }

    public func data(forKey key: String) -> Data? {
        storage[key]
    }

    public func set(_ data: Data, forKey key: String) throws {
        if shouldFailWrite { throw StoreFailure() }
        storage[key] = data
    }
}
