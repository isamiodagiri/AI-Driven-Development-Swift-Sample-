import SwiftUI

/// リポジトリ1行。**検索とお気に入りが同じ部品を使う**（TS-97）。
/// Feature 同士は参照できないので、共有する見た目はここにしか置けない。
public struct AppRepoRow: View {
    /// 文字の大きさに合わせてアバターも大きくする。文字だけが伸びると釣り合いが崩れる。
    @ScaledMetric(relativeTo: .headline) private var avatarSize = AppSize.avatar
    /// AX サイズでは行を切り詰めず、折り返す（裁定 D-19）。
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let display: RepoRowDisplay
    private let onToggleFavorite: () -> Void

    public init(display: RepoRowDisplay, onToggleFavorite: @escaping () -> Void) {
        self.display = display
        self.onToggleFavorite = onToggleFavorite
    }

    public var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            avatar
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(display.fullName)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

                // 説明が無い行では、説明そのものを出さない（空行を作らない ＝ AC-10）
                if let description = display.description {
                    Text(description)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .accessibilityIdentifier(AppIdentifier.repoRowDescription)
                }

                metadata
            }
            Spacer(minLength: AppSpacing.sm)
            favoriteButton
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
        .accessibilityIdentifier(AppIdentifier.repoRow)
    }

    private var avatar: some View {
        AsyncImage(url: display.avatarURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            RoundedRectangle(cornerRadius: AppRadius.md).fill(AppColor.border)
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        // 見た目だけの要素。読み上げの邪魔になる
        .accessibilityHidden(true)
    }

    /// スター・言語・更新日。
    ///
    /// **AX サイズでは横に3つ並べると必ず溢れる**ので、そのときだけ縦に積む（裁定 D-19）。
    /// `ViewThatFits` を使わないのは、入る/入らないの判定が端末幅に依存して
    /// テストから観測できなくなるためである。
    @ViewBuilder
    private var metadata: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xs))
            : AnyLayout(HStackLayout(spacing: AppSpacing.md))

        layout {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "star.fill").foregroundStyle(AppColor.star)
                Text(display.starsText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("スター \(display.starsText)")

            // 言語が無い行では、言語そのものを出さない（AC-11）
            if let language = display.language {
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(AppColor.accent)
                        .frame(width: AppSize.languageDot, height: AppSize.languageDot)
                        .accessibilityHidden(true)
                    Text(language)
                }
                .accessibilityIdentifier(AppIdentifier.repoRowLanguage)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("言語 \(language)")
            }

            Text(display.updatedText)
                .accessibilityLabel("更新 \(display.updatedText)")
        }
        .font(AppTypography.caption)
        .foregroundStyle(AppColor.textSecondary)
    }

    private var favoriteButton: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: display.isFavorite ? "star.fill" : "star")
                .foregroundStyle(display.isFavorite ? AppColor.star : AppColor.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AppIdentifier.repoRowFavoriteButton)
        .accessibilityLabel(display.isFavorite ? "お気に入りから外す" : "お気に入りに追加")
    }
}
