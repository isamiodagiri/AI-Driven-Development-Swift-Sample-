/// 通信の口。実装を差し替えられるのは合成ルートだけである。
public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}
