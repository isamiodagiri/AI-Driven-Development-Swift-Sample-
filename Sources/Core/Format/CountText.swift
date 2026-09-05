import Foundation

public enum CountText {
    /// 1,000 以上は `67.0k` の形に丸める。1,000 未満はそのまま（AC-12）。
    ///
    /// 丸めは **ViewModel の仕事**で、View は出来上がった文字列を受け取るだけである。
    public static func compact(_ value: Int) -> String {
        guard value >= 1000 else { return String(value) }
        let thousands = Double(value) / 1000
        return String(format: "%.1fk", thousands)
    }
}
