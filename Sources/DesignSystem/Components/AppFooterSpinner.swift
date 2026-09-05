import SwiftUI

/// 追加読み込み中の印。**既存の行を消さずに**末尾へ出す（AC-21）。
public struct AppFooterSpinner: View {
    public init() {}

    public var body: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(AppSpacing.md)
        .accessibilityIdentifier(AppIdentifier.footerSpinner)
    }
}
