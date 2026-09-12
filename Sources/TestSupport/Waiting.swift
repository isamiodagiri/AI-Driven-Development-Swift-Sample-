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

/// **起きてはいけないこと**に、起きる機会を与える。
///
/// 「これ以上は起きない」（例: 呼び出しが増えない・状態が変わらない）を確かめる前に呼ぶ。
/// 条件が満たされた瞬間に返るので、**壊れているときは速く赤くなり、正しいときだけ待ち切る**。
///
/// 固定時間の `settle()` で代用してはならない。
/// 遅い機械では待ち時間のほうが先に尽き、**壊れた実装でも緑になる**
/// — CI のランナーで実際に起きた（docs/04-test-strategy.md §6-5）。
///
/// ```swift
/// await waitForUnwanted { await client.requestCount > 1 }
/// #expect(await client.requestCount == 1)
/// ```
public func waitForUnwanted(
    timeout: Duration = .seconds(2),
    _ condition: @Sendable () async -> Bool
) async {
    await waitUntil(timeout: timeout, condition)
}

/// メインアクタ上で、**起きてはいけないこと**に起きる機会を与える。
///
/// `ViewModel` の状態を見るときはこちらを使う（`@MainActor` なので外からは読めない）。
@MainActor
public func waitForUnwantedOnMain(
    timeout: Duration = .seconds(2),
    _ condition: () -> Bool
) async {
    await waitUntilOnMain(timeout: timeout, condition)
}

/// 進行中の処理が落ち着くまで、少しだけ待つ。
///
/// **待つ相手が観測できないときの最後の手段**である。
/// 「起きてはいけないこと」を確かめる前には `waitForUnwanted` を使うこと。
public func settle(_ duration: Duration = .milliseconds(150)) async {
    try? await Task.sleep(for: duration)
}
