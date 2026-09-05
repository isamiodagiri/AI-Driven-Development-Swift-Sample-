import Foundation

public enum RelativeDateText {
    /// 7日以内は相対表記、それ以前は `yyyy/MM/dd`（AC-13）。
    ///
    /// `RelativeDateTimeFormatter` を使わないのは、**出力が実行環境のロケールで変わる**ため。
    /// 基準時刻 `now` を必ず受け取るのは、テストで固定するためである。
    public static func text(for date: Date?, now: Date) -> String {
        guard let date else { return "" }
        let seconds = now.timeIntervalSince(date)

        if seconds < 60 { return "たった今" }
        if seconds < 3600 { return "\(Int(seconds / 60))分前" }
        if seconds < 86400 { return "\(Int(seconds / 3600))時間前" }
        if seconds < 86400 * 7 { return "\(Int(seconds / 86400))日前" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    /// レート制限が明けるまでの分数。切り上げる（「あと 0 分」と出さない）。
    public static func minutesUntil(_ date: Date, from now: Date) -> Int {
        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else { return 0 }
        return Int((seconds / 60).rounded(.up))
    }
}
