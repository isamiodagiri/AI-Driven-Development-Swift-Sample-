import SwiftUI

/// 読み込み中の1行。スピナーではなく実レイアウトを模した形にして、
/// 確定したときのレイアウトシフトを避ける（docs/03-screens.md §0-2）。
public struct AppSkeletonRow: View {
    @State private var isDim = false

    public init() {}

    public var body: some View {
        HStack(spacing: AppSpacing.md) {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .fill(AppColor.border)
                .frame(width: AppSize.avatar, height: AppSize.avatar)
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(AppColor.border)
                    .frame(height: AppSize.skeletonLine)
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(AppColor.border)
                    .frame(width: AppSize.skeletonRow * 2, height: AppSize.skeletonLine)
            }
        }
        .opacity(isDim ? 0.4 : 0.7)
        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isDim)
        .onAppear { isDim = true }
        .accessibilityIdentifier(AppIdentifier.skeletonRow)
        .accessibilityHidden(true)
    }
}
