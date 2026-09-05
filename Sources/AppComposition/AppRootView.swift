import DesignSystem
import FavoriteFeature
import RepoDetailFeature
import SearchFeature
import SwiftUI

/// 遷移先。**Feature 同士は参照できない**ので、経路を知ってよいのはこの層だけである。
public enum AppRoute: Hashable {
    case detail(RepoRowDisplay)
}

/// タブと遷移の結線。Feature は「押された」としか言わない（docs/01-architecture.md §3-4）。
public struct AppRootView: View {
    private let dependencies: AppDependencies
    @Environment(\.openURL) private var openURL
    @State private var searchPath: [AppRoute] = []
    @State private var favoritePath: [AppRoute] = []

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        TabView {
            NavigationStack(path: $searchPath) {
                SearchScreen(
                    makeViewModel: { makeSearchViewModel() },
                    onSelectRepo: { display in searchPath.append(.detail(display)) }
                )
                .navigationDestination(for: AppRoute.self) { route in
                    destination(route)
                }
            }
            .tabItem { Label("検索", systemImage: "magnifyingglass") }

            NavigationStack(path: $favoritePath) {
                FavoriteScreen(
                    makeViewModel: { makeFavoriteViewModel() },
                    onSelectRepo: { display in favoritePath.append(.detail(display)) }
                )
                .navigationDestination(for: AppRoute.self) { route in
                    destination(route)
                }
            }
            .tabItem { Label("お気に入り", systemImage: "star.fill") }
        }
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .detail(let display):
            RepoDetailScreen(
                makeViewModel: { makeDetailViewModel(display: display) },
                onOpenURL: { url in openURL(url) }
            )
        }
    }

    private func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(
            searchRepos: dependencies.searchRepos,
            loadMoreRepos: dependencies.loadMoreRepos,
            toggleFavorite: dependencies.toggleFavorite,
            observeFavoriteIDs: dependencies.observeFavoriteIDs
        )
    }

    private func makeFavoriteViewModel() -> FavoriteViewModel {
        FavoriteViewModel(
            observeFavorites: dependencies.observeFavorites,
            toggleFavorite: dependencies.toggleFavorite
        )
    }

    private func makeDetailViewModel(display: RepoRowDisplay) -> RepoDetailViewModel {
        RepoDetailViewModel(
            ownerLogin: display.ownerLogin,
            repoName: display.name,
            initialDisplay: display,
            fetchRepoDetail: dependencies.fetchRepoDetail,
            toggleFavorite: dependencies.toggleFavorite,
            observeFavoriteIDs: dependencies.observeFavoriteIDs
        )
    }
}
