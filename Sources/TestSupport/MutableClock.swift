import Foundation
import os

/// 進められる時計。`addedAt` の差や、時刻に依存する並びをテストで作るために使う。
///
/// 実時間を待たずに時刻だけを進める。複数の Task から読まれるので `Sendable` が要るが、
/// `OSAllocatedUnfairLock` が状態ごと保護するため、検査を黙らせずに済んでいる（INV-4）。
public final class MutableClock: Sendable {
    private let current: OSAllocatedUnfairLock<Date>

    public init(start: Date) {
        current = OSAllocatedUnfairLock(initialState: start)
    }

    /// 現在時刻。`now: { clock.now }` の形で注入する。
    public var now: Date {
        current.withLock { $0 }
    }

    public func advance(by seconds: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(seconds) }
    }
}
