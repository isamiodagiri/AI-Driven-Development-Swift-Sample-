import SwiftUI

/// フォントの唯一の置き場。View は `.font(.system(...))` を書けない（INV-6）。
public enum AppTypography {
    public static let title = Font.title2.weight(.semibold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let captionBold = Font.caption.weight(.semibold)
}
