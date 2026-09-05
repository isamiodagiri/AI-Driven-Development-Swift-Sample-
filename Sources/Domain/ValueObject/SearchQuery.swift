import Foundation

/// 検索語。**空白を取り除いた結果が空なら作れない**（UC-001 AC-5）。
///
/// 「空では検索しない」を型で担保するので、これを受け取る側は空を気にしなくてよい。
public struct SearchQuery: Sendable, Hashable {
    public let rawValue: String

    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        rawValue = trimmed
    }
}
