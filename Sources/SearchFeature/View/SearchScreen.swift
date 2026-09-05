import DesignSystem
import SwiftUI

/// 検索画面。**State を描くだけ**で、判断は持たない（INV-10）。
/// 参照する ViewModel は1つだけである（INV-9）。
public struct SearchScreen: View {
    @StateObject private var viewModel: SearchViewModel
    private let onSelectRepo: (RepoRowDisplay) -> Void

    public init(
        makeViewModel: @escaping @MainActor () -> SearchViewModel,
        onSelectRepo: @escaping (RepoRowDisplay) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: makeViewModel())
        self.onSelectRepo = onSelectRepo
    }

    public var body: some View {
        content
            .navigationTitle("検索")
            .searchable(text: $viewModel.query, prompt: "リポジトリを検索")
            .onAppear { viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.displayState.phase {
        case .initial:
            AppEmptyView(
                title: "リポジトリを検索",
                message: "キーワードを入力すると、GitHub の公開リポジトリを検索します",
                systemImage: "magnifyingglass"
            )
        case .loading:
            skeleton
        case .loaded(let rows, let isLoadingMore):
            list(rows: rows, isLoadingMore: isLoadingMore)
        case .empty(let query):
            AppEmptyView(
                title: "“\(query)” に一致するリポジトリはありません",
                message: "別のキーワードでお試しください",
                systemImage: "questionmark.folder"
            )
        case .failed(let error):
            AppErrorView(state: error) { viewModel.retry() }
        }
    }

    private var skeleton: some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(SearchScreen.skeletonRowIDs, id: \.self) { _ in
                AppSkeletonRow()
            }
            Spacer()
        }
        .padding(AppSpacing.lg)
    }

    private func list(rows: [SearchRow], isLoadingMore: Bool) -> some View {
        List {
            ForEach(rows) { row in
                AppRepoRow(display: row.display) {
                    viewModel.toggleFavorite(rowID: row.display.id)
                }
                .onTapGesture { onSelectRepo(row.display) }
                .onAppear {
                    if row.isLoadMoreTrigger {
                        viewModel.onReachedLoadMoreTrigger()
                    }
                }
            }
            if isLoadingMore {
                AppFooterSpinner()
            }
        }
        .listStyle(.plain)
    }

    /// スケルトンは6行（docs/03-screens.md §0-2）。
    private static let skeletonRowIDs = [0, 1, 2, 3, 4, 5]
}
