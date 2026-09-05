import DesignSystem
import SwiftUI

/// 詳細画面。**State を描くだけ**である。
public struct RepoDetailScreen: View {
    @StateObject private var viewModel: RepoDetailViewModel
    /// AX サイズでは横並びをやめる（裁定 D-19）。
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 「GitHub で開く」を押されたことだけを外へ伝える。
    ///
    /// `@Environment(\.openURL)` を View の中で直に呼ばないのは、
    /// **どの URL を渡したかを外から観測できなくなる**ためである（TS-76）。
    /// 検索・お気に入りが `onSelectRepo` を受け取っているのと同じ形にしてある。
    private let onOpenURL: (URL) -> Void

    public init(
        makeViewModel: @escaping @MainActor () -> RepoDetailViewModel,
        onOpenURL: @escaping (URL) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: makeViewModel())
        self.onOpenURL = onOpenURL
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                content
            }
            .padding(AppSpacing.lg)
        }
        .navigationTitle("詳細")
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.phase {
        case .loading:
            VStack(spacing: AppSpacing.md) {
                AppSkeletonRow()
                AppSkeletonRow()
            }
        case .partial(let header, let stats, let error):
            headerView(header)
            statsView(stats)
            openButton
            if let error {
                VStack(spacing: AppSpacing.sm) {
                    AppErrorView(state: error) { viewModel.retry() }
                }
                .accessibilityIdentifier(AppIdentifier.detailPartialError)
            }
        case .loaded(let header, let stats, let fields, let topics):
            headerView(header)
            statsView(stats)
            fieldsView(fields)
            topicsView(topics)
            openButton
        case .failed(let error):
            AppErrorView(state: error) { viewModel.retry() }
        }
    }

    private func headerView(_ header: RepoDetailHeader) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            AsyncImage(url: header.display.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: AppRadius.lg).fill(AppColor.border)
            }
            .frame(width: AppSize.avatarLarge, height: AppSize.avatarLarge)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(header.display.fullName)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColor.textPrimary)
                if let description = header.display.description {
                    Text(description)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textSecondary)
                }
                HStack(spacing: AppSpacing.sm) {
                    if header.isArchived {
                        Text("アーカイブ済み")
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColor.danger)
                            .accessibilityIdentifier(AppIdentifier.detailArchivedBadge)
                    }
                    if header.isFork {
                        Text("フォーク")
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColor.textSecondary)
                            .accessibilityIdentifier(AppIdentifier.detailForkBadge)
                    }
                }
            }
            Spacer(minLength: AppSpacing.sm)
            favoriteButton
        }
    }

    private var favoriteButton: some View {
        Button {
            viewModel.toggleFavorite()
        } label: {
            Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                .foregroundStyle(viewModel.isFavorite ? AppColor.star : AppColor.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AppIdentifier.repoRowFavoriteButton)
        .accessibilityLabel(viewModel.isFavorite ? "お気に入りから外す" : "お気に入りに追加")
    }

    /// 数値バッジの列。
    ///
    /// **AX サイズでは4つ横に並べると溢れる**ので、そのときだけ縦に積む（裁定 D-19）。
    @ViewBuilder
    private func statsView(_ stats: RepoDetailStats) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.sm))
            : AnyLayout(HStackLayout(spacing: AppSpacing.sm))

        layout {
            AppStatBadge(systemImage: "star", text: stats.starsText, label: "スター")
            AppStatBadge(systemImage: "tuningfork", text: stats.forksText, label: "フォーク")
            if let watchers = stats.watchersText {
                AppStatBadge(systemImage: "eye", text: watchers, label: "ウォッチャー")
            }
            if let issues = stats.openIssuesText {
                AppStatBadge(systemImage: "exclamationmark.circle", text: issues, label: "未解決の Issue")
            }
        }
    }

    private func fieldsView(_ fields: [RepoDetailField]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ForEach(fields) { field in
                HStack {
                    Text(field.label)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(field.value)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textPrimary)
                }
                .accessibilityIdentifier(field.id == "license" ? AppIdentifier.detailLicense : field.id)
            }
        }
    }

    @ViewBuilder
    private func topicsView(_ topics: [String]) -> some View {
        // トピックが無いときは行そのものを出さない（AC-5）
        if !topics.isEmpty {
            // 数が読めないので折り返す。HStack だと1文字ずつ縦に折れて読めなくなる
            AppFlowLayout(spacing: AppSpacing.sm) {
                ForEach(topics, id: \.self) { topic in
                    Text(topic)
                        .font(AppTypography.caption)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColor.surface, in: Capsule())
                }
            }
            .accessibilityIdentifier(AppIdentifier.detailTopics)
        }
    }

    @ViewBuilder
    private var openButton: some View {
        if let url = viewModel.state.htmlURL {
            Button("GitHub で開く") { onOpenURL(url) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(AppIdentifier.detailOpenInBrowser)
        }
    }
}
