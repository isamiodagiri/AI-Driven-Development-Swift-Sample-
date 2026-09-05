import Foundation

/// 失敗の**文言の唯一の置き場**（docs/03-screens.md §0-3）。
///
/// 3つの Feature が同じ文言を出すので、ここに1つだけ置く。
/// どの `GitHubError` をどれに対応させるかは Feature 側（Presentation）が決める。
extension AppErrorState {
    public static let offline = AppErrorState(
        title: "つながりませんでした",
        message: "ネットワークの状態を確認してください",
        isRetryable: true
    )

    public static let timeout = AppErrorState(
        title: "時間がかかっています",
        message: "電波の良い場所でもう一度お試しください",
        isRetryable: true
    )

    /// `minutes` が nil のときは分数を出さない。**嘘の数字を出さない**（AC-31b）。
    public static func rateLimited(minutes: Int?) -> AppErrorState {
        let message = minutes.map { "あと \($0) 分で再開できます" } ?? "しばらく待ってからお試しください"
        return AppErrorState(title: "回数の上限に達しました", message: message, isRetryable: false)
    }

    public static let notFound = AppErrorState(
        title: "見つかりませんでした",
        message: "削除されたか、非公開になった可能性があります",
        isRetryable: false
    )

    public static func invalidQuery(reason: String) -> AppErrorState {
        AppErrorState(title: "検索できませんでした", message: reason, isRetryable: false)
    }

    public static let unauthorized = AppErrorState(
        title: "認証に失敗しました",
        message: "アクセストークンの設定を確認してください",
        isRetryable: false
    )

    public static let generic = AppErrorState(
        title: "読み込めませんでした",
        message: "時間をおいてもう一度お試しください",
        isRetryable: true
    )
}
