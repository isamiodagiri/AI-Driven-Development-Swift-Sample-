import Foundation

/// 業務が知ってよい失敗のすべて。HTTP のステータスコードは**この型より上には出さない**。
/// 写像の表は docs/02-github-api.md §4 が正で、写像するのは Repository 層だけである。
public enum GitHubError: Error, Equatable, Sendable {
    case offline
    case timeout
    /// 403 / 429 かつ `x-ratelimit-remaining: 0`。`resetAt` は無いこともある（AC-31b）。
    case rateLimited(resetAt: Date?)
    case unauthorized
    case notFound
    case invalidQuery(reason: String)
    case server(status: Int)
    /// 応答の形が違う。`unknown` にまとめない — API の変更に気づける唯一の信号である。
    case decoding
    case unknown
}
