import SwiftUI

/// 数値バッジ（スター・フォーク・ウォッチャー・Issue）。
///
/// **アイコンと数字だけでは VoiceOver に何の数か伝わらない**ので、
/// 読み上げ用の名前を必ず受け取る（裁定 D-19）。
public struct AppStatBadge: View {
    private let systemImage: String
    private let text: String
    private let label: String

    public init(systemImage: String, text: String, label: String) {
        self.systemImage = systemImage
        self.text = text
        self.label = label
    }

    public var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(AppTypography.captionBold)
        .foregroundStyle(AppColor.textSecondary)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.md))
        // アイコンと数字を別々に読ませない。「スター 1.2k」と1つに読ませる
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(text)")
    }
}
