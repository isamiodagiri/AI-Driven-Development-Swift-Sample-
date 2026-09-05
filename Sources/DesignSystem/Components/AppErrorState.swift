/// 失敗の見せ方。**文言を決めるのは ViewModel**で、ここはその入れ物である。
public struct AppErrorState: Sendable, Equatable {
    public let title: String
    public let message: String
    /// レート制限のときは再試行させない（AC-31・AC-32）。
    public let isRetryable: Bool

    public init(title: String, message: String, isRetryable: Bool) {
        self.title = title
        self.message = message
        self.isRetryable = isRetryable
    }
}
