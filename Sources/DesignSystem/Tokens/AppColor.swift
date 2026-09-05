import SwiftUI

/// 色の唯一の置き場。View は `Color` を作れない（INV-6）。
///
/// **明用・暗用の2系統を持たない**（裁定 D-21）。
/// システムのセマンティックカラーと不透明度だけで組み、明暗の切り替えは OS に任せる。
/// ただし**明暗それぞれの見た目は確かめていない**（理由は docs/05-decisions.md D-21）。
public enum AppColor {
    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary
    public static let background = Color.gray.opacity(0.06)
    public static let surface = Color.gray.opacity(0.12)
    public static let border = Color.gray.opacity(0.25)
    public static let accent = Color.accentColor
    public static let star = Color.yellow
    public static let danger = Color.red
}
