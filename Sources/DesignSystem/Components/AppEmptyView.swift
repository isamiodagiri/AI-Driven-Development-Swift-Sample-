import SwiftUI

public struct AppEmptyView: View {
    private let title: String
    private let message: String
    private let systemImage: String

    public init(title: String, message: String, systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(AppTypography.title)
                .foregroundStyle(AppColor.textSecondary)
            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(AppIdentifier.emptyView)
    }
}
