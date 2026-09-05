import OSLog

/// ログの口。`.decoding` のような「握りつぶすと API の変更に気づけなくなる」失敗をここへ残す。
public enum AppLogger {
    private static let logger = Logger(subsystem: "com.example.GitHubSample", category: "app")

    public static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    public static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
