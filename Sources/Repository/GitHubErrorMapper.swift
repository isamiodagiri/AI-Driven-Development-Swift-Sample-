import Core
import Domain
import Foundation

/// HTTP → `GitHubError` の写像。**この1箇所に閉じる**（docs/02-github-api.md §4 が正）。
/// UseCase と ViewModel はステータスコードを見ない。
enum GitHubErrorMapper {
    /// 2xx なら nil。それ以外は対応する `GitHubError`。
    static func error(from response: HTTPResponse, now: @Sendable () -> Date) -> GitHubError? {
        switch response.statusCode {
        case 200..<300:
            return nil
        case 401:
            return .unauthorized
        case 403, 429:
            // 403 は理由が複数ある。レート制限だと判別できる手掛かりは remaining だけである。
            if response.header("x-ratelimit-remaining") == "0" {
                return .rateLimited(resetAt: resetDate(from: response, now: now))
            }
            return .unknown
        case 404:
            return .notFound
        case 422:
            return .invalidQuery(reason: validationReason(from: response))
        case 500...599:
            return .server(status: response.statusCode)
        default:
            return .unknown
        }
    }

    /// 通信そのものの失敗。
    ///
    /// **キャンセルは写像しない**（そのまま投げ返す）。エラー表示に変えてしまうと、
    /// 打鍵のたびに「失敗しました」が出る（AC-18・AC-19）。
    static func error(from error: any Error) -> any Error {
        if error is CancellationError {
            return error
        }
        guard let urlError = error as? URLError else {
            return GitHubError.unknown
        }
        switch urlError.code {
        case .cancelled:
            return error
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return GitHubError.offline
        case .timedOut:
            return GitHubError.timeout
        default:
            return GitHubError.unknown
        }
    }

    private static func resetDate(from response: HTTPResponse, now: @Sendable () -> Date) -> Date? {
        // 二次レート制限では retry-after（秒）が来る。あれば reset より優先する。
        if let retryAfter = response.header("retry-after"), let seconds = TimeInterval(retryAfter) {
            return now().addingTimeInterval(seconds)
        }
        if let reset = response.header("x-ratelimit-reset"), let epoch = TimeInterval(reset) {
            return Date(timeIntervalSince1970: epoch)
        }
        // 分からないときは nil。嘘の待ち時間を出さない（AC-31b）。
        return nil
    }

    private static func validationReason(from response: HTTPResponse) -> String {
        let decoder = JSONDecoder()
        guard let dto = try? decoder.decode(ValidationErrorDTO.self, from: response.body) else {
            return "検索の条件を見直してください"
        }
        return dto.errors?.first?.message ?? dto.message ?? "検索の条件を見直してください"
    }
}
