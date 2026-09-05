import Foundation

/// 条件が満たされるまで短く待つ。
///
/// 固定時間の `Task.sleep` を書かないための道具である（待ち時間そのものをテストにしない）。
/// 満たされなければ時間切れで戻るので、呼んだ側の `#expect` が失敗として現れる。
public func waitUntil(
    timeout: Duration = .seconds(2),
    pollingInterval: Duration = .milliseconds(5),
    _ condition: @Sendable () async -> Bool
) async {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try? await Task.sleep(for: pollingInterval)
    }
}

/// メインアクタ上で条件が満たされるまで待つ。
///
/// `ViewModel` は `@MainActor` なので、`await` で main を明け渡さないと
/// その中の `Task` が一度も進まない。
@MainActor
public func waitUntilOnMain(
    timeout: Duration = .seconds(2),
    pollingInterval: Duration = .milliseconds(5),
    _ condition: () -> Bool
) async {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if condition() { return }
        try? await Task.sleep(for: pollingInterval)
    }
}

/// 進行中の処理が落ち着くまで、少しだけ待つ。
/// 「これ以上は起きない」（例: 呼び出しが増えない）ことを確かめるために使う。
public func settle(_ duration: Duration = .milliseconds(150)) async {
    try? await Task.sleep(for: duration)
}
