import Core
import Foundation

/// 通信の差し替え。**応答を保留し、任意の順で解放できる**のがこのスタブの肝である。
///
/// 解放順を握れないと「古い応答が新しい結果を上書きしない」（AC-17）を確かめられない
/// — 実装が正しくても、たまたま順番に返って緑になるだけになる（docs/04-test-strategy.md §5-2）。
public actor StubHTTPClient: HTTPClient {
    public enum Outcome: Sendable {
        case success(HTTPResponse)
        /// `any Error` は `Sendable` ではないので、`& Sendable` まで要求する
        /// （チェックを外した準拠を書かずに済ませるため ＝ INV-4）。
        case failure(any Error & Sendable)
    }

    /// 検索語ごとに応答を決める。`nil` キーは既定の応答。
    private var outcomes: [String: Outcome] = [:]
    private var defaultOutcome: Outcome?
    private var manualKeys: Set<String> = []
    private var releasedKeys: Set<String> = []
    /// キャンセルされても止まらない要求。
    /// 「`cancel()` が間に合わず、古い応答が返り切ってしまった」状況を作るために要る（AC-17）。
    private var ignoreCancellationKeys: Set<String> = []

    public private(set) var requests: [HTTPRequest] = []

    /// **応答を返し終えた要求**のキー。
    ///
    /// 「古い応答が後から届いても上書きしない」（AC-17）は、
    /// **古い応答が実際に届いた後で**状態を見なければ確かめられない。
    /// 固定時間の待ちで代用すると、届く前に測って**偽の緑**になる
    /// — 負荷をかけた変異検証で実際に起きた（docs/04-test-strategy.md §6-4）。
    public private(set) var deliveredKeys: [String] = []

    /// **キャンセルされて終わった要求**のキー。
    ///
    /// 「前の検索を止めた」（AC-16）は、これが無いと観測できない。
    /// 状態だけを見ると、世代番号で古い応答を弾いていても同じ絵になるためである
    /// — `cancel()` を消しても誰も赤くならない状態が実際にあった（docs/04-test-strategy.md §6-3）。
    public private(set) var cancelledKeys: [String] = []

    public init() {}

    // MARK: - 仕込み

    public func setDefault(_ outcome: Outcome) {
        defaultOutcome = outcome
    }

    /// 検索語（と、必要ならページ番号）で応答を決める。
    ///
    /// ページを指定すると `swift#2` のようなキーになり、そのページだけに効く。
    /// 指定しなければ、その検索語のすべてのページに効く。
    public func set(
        _ outcome: Outcome,
        forQuery query: String,
        page: Int? = nil,
        manualRelease: Bool = false,
        ignoresCancellation: Bool = false
    ) {
        let query = page.map { "\(query)#\($0)" } ?? query
        outcomes[query] = outcome
        if manualRelease {
            manualKeys.insert(query)
        }
        if ignoresCancellation {
            ignoreCancellationKeys.insert(query)
        }
    }

    /// 保留していた応答を返させる。
    public func release(_ query: String) {
        releasedKeys.insert(query)
    }

    // MARK: - 観測

    public var requestCount: Int { requests.count }

    public func requestedQueries() -> [String] {
        requests.compactMap { request in
            request.queryItems.first(where: { $0.name == "q" })?.value
        }
    }

    public func requestedPaths() -> [String] {
        requests.map { $0.url.path() }
    }

    /// キャンセルされて終わった要求の検索語。
    public func cancelledQueries() -> [String] {
        cancelledKeys
    }

    /// 応答を返し終えた要求の検索語。
    public func deliveredQueries() -> [String] {
        deliveredKeys
    }

    /// 仕込まれているキーのうち、もっとも具体的なものを選ぶ（`swift#2` → `swift` → パス）。
    private func key(for request: HTTPRequest) -> String {
        let query = request.queryItems.first(where: { $0.name == "q" })?.value
        let page = request.queryItems.first(where: { $0.name == "page" })?.value
        var candidates: [String] = []
        if let query, let page {
            candidates.append("\(query)#\(page)")
        }
        if let query {
            candidates.append(query)
        }
        candidates.append(request.url.path())
        return candidates.first(where: { outcomes[$0] != nil }) ?? candidates.first ?? ""
    }

    // MARK: - HTTPClient

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        let key = key(for: request)

        let ignoresCancellation = ignoreCancellationKeys.contains(key)
        if manualKeys.contains(key) {
            while !releasedKeys.contains(key) {
                if !ignoresCancellation, Task.isCancelled {
                    cancelledKeys.append(key)
                    throw CancellationError()
                }
                try? await Task.sleep(for: .milliseconds(2))
            }
        }

        if !ignoresCancellation, Task.isCancelled {
            cancelledKeys.append(key)
            try Task.checkCancellation()
        }

        guard let outcome = outcomes[key] ?? defaultOutcome else {
            throw URLError(.unsupportedURL)
        }
        deliveredKeys.append(key)
        switch outcome {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}
