import Foundation

/// 層をまたぐ「応答」の表現。
///
/// `headers` のキーは**小文字に正規化してある**。HTTP のヘッダ名は大文字小文字を区別しないので、
/// 受け取る側が `x-ratelimit-remaining` と `X-RateLimit-Remaining` の両方を気にせずに済むようにする。
public struct HTTPResponse: Sendable, Equatable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers.reduce(into: [:]) { $0[$1.key.lowercased()] = $1.value }
        self.body = body
    }

    public func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }
}
