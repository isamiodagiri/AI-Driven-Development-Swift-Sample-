import Core
import DesignSystem
import Domain
import Foundation

/// `GitHubError` → 画面に出す失敗の形。
///
/// **文言そのものは DesignSystem が持ち**、ここは対応づけだけを持つ。
/// 3つの Feature が同じ対応づけをするので、1箇所に置く。
public enum GitHubErrorPresenter {
    public static func errorState(for error: any Error, now: Date) -> AppErrorState {
        guard let error = error as? GitHubError else { return .generic }
        switch error {
        case .offline:
            return .offline
        case .timeout:
            return .timeout
        case .rateLimited(let resetAt):
            let minutes = resetAt.map { RelativeDateText.minutesUntil($0, from: now) }
            return .rateLimited(minutes: minutes)
        case .notFound:
            return .notFound
        case .invalidQuery(let reason):
            return .invalidQuery(reason: reason)
        case .unauthorized:
            return .unauthorized
        case .server, .decoding, .unknown:
            return .generic
        }
    }

    /// キャンセルは失敗ではない。**状態を変えてはいけない**ので、呼ぶ側が先にこれで弾く（AC-18）。
    public static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
