import SwiftUI

/// 失敗の表示。**再試行ボタンを出すかどうかは `state.isRetryable` が決める**
/// （レート制限中に押させると、待ち時間が伸びるだけである ＝ AC-32）。
public struct AppErrorView: View {
    private let state: AppErrorState
    private let onRetry: () -> Void

    public init(state: AppErrorState, onRetry: @escaping () -> Void) {
        self.state = state
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text(state.title)
                .font(AppTypography.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text(state.message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            if state.isRetryable {
                Button("再試行", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(AppIdentifier.errorRetryButton)
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(AppIdentifier.errorView)
    }
}
