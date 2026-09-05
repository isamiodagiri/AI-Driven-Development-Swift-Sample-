import DesignSystem
import SwiftUI

/// お気に入り画面。行の見た目は検索と同じ部品（`AppRepoRow`）を使う。
public struct FavoriteScreen: View {
    @StateObject private var viewModel: FavoriteViewModel
    private let onSelectRepo: (RepoRowDisplay) -> Void

    public init(
        makeViewModel: @escaping @MainActor () -> FavoriteViewModel,
        onSelectRepo: @escaping (RepoRowDisplay) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: makeViewModel())
        self.onSelectRepo = onSelectRepo
    }

    public var body: some View {
        content
            .navigationTitle("お気に入り")
            .onAppear { viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state.phase {
        case .loading:
            AppSkeletonRow()
                .padding(AppSpacing.lg)
        case .empty:
            AppEmptyView(
                title: "お気に入りはまだありません",
                message: "検索した結果の ☆ を押すと、ここに集まります",
                systemImage: "star"
            )
        case .loaded(let rows):
            list(rows: rows)
        }
    }

    private func list(rows: [RepoRowDisplay]) -> some View {
        List {
            ForEach(rows) { row in
                AppRepoRow(display: row) {
                    viewModel.remove(rowID: row.id)
                }
                .onTapGesture { onSelectRepo(row) }
                .swipeActions(edge: .trailing) {
                    Button("削除", role: .destructive) {
                        viewModel.remove(rowID: row.id)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}
