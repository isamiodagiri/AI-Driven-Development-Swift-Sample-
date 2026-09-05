import DesignSystem
import Domain
import Foundation
import Presentation
import Repository
import SwiftUI
import Testing
import TestSupport
import UseCase
import ViewInspector

@testable import RepoDetailFeature

/// UC-002 の View 層（TS-72〜TS-76）。
///
/// 「State に出ているのに画面に出ていない」だけを狙う（[04 §3](../../docs/04-test-strategy.md)）。
@MainActor
@Suite("UC-002 View: 詳細")
struct RepoDetailScreenViewTests {
    @Test("TS-72 archived ならアーカイブ済みのバッジが出る")
    func showsArchivedBadge() async throws {
        let archived = try await Self.screen(detail: .stub(isArchived: true))
        let normal = try await Self.screen(detail: .stub(isArchived: false))

        #expect(throws: Never.self) {
            try archived.find(viewWithAccessibilityIdentifier: AppIdentifier.detailArchivedBadge)
        }
        #expect(throws: (any Error).self) {
            try normal.find(viewWithAccessibilityIdentifier: AppIdentifier.detailArchivedBadge)
        }
    }

    @Test("TS-73 fork ならフォークの印が出る")
    func showsForkBadge() async throws {
        let forked = try await Self.screen(detail: .stub(isFork: true))
        let normal = try await Self.screen(detail: .stub(isFork: false))

        #expect(throws: Never.self) {
            try forked.find(viewWithAccessibilityIdentifier: AppIdentifier.detailForkBadge)
        }
        #expect(throws: (any Error).self) {
            try normal.find(viewWithAccessibilityIdentifier: AppIdentifier.detailForkBadge)
        }
    }

    @Test("TS-74 license が nil でも「ライセンス」の行は出る（消さずに「なし」と書く）")
    func showsLicenseRowEvenWhenNil() async throws {
        let screen = try await Self.screen(detail: .stub(licenseName: nil))

        let row = try screen.find(viewWithAccessibilityIdentifier: AppIdentifier.detailLicense)
        #expect(throws: Never.self) { try row.find(text: "なし") }
    }

    @Test("TS-75 topics が空ならトピックの行そのものが無い")
    func omitsTopicsWhenEmpty() async throws {
        let withTopics = try await Self.screen(detail: .stub(topics: ["swift"]))
        let withoutTopics = try await Self.screen(detail: .stub(topics: []))

        #expect(throws: Never.self) {
            try withTopics.find(viewWithAccessibilityIdentifier: AppIdentifier.detailTopics)
        }
        #expect(throws: (any Error).self) {
            try withoutTopics.find(viewWithAccessibilityIdentifier: AppIdentifier.detailTopics)
        }
    }

    @Test("TS-76 「GitHub で開く」は html_url を開く")
    func opensHTMLURL() async throws {
        let expected = try #require(URL(string: "https://github.com/owner-1/repo-1"))
        let opened = Box<URL?>(nil)
        let sut = RepoDetailViewModelTests.makeSUT(initialDisplay: nil)
        await sut.client.setDefault(.success(Fixture.response("repo_detail_ok")))
        sut.viewModel.onAppear()
        await waitUntilOnMain { sut.viewModel.state.htmlURL != nil }

        let screen = RepoDetailScreen(makeViewModel: { sut.viewModel }, onOpenURL: { opened.value = $0 })
        let button = try screen.inspect().find(viewWithAccessibilityIdentifier: AppIdentifier.detailOpenInBrowser)
        try button.button().tap()

        #expect(sut.viewModel.state.htmlURL == expected)
        #expect(opened.value == expected)
    }

    @Test("TS-102 数値バッジは「スター 1.2k」のように1つの語として読まれる")
    func statBadgeReadsAsOneLabel() async throws {
        let screen = try await Self.screen(detail: .stub(summary: .stub(stars: 1200)))

        // アイコンと数字が別々に読まれると、何の数か伝わらない（裁定 D-19）
        let badge = try screen.find(viewWithAccessibilityLabel: "スター 1.2k")
        #expect(try badge.accessibilityLabel().string() == "スター 1.2k")
    }

    // MARK: - 補助

    /// 詳細を1件読み込み終えた画面を作る。
    ///
    /// `RepoDetail` から `HTTPResponse` を組むのではなく、**Repository を差し替えて**渡す。
    /// View のテストで JSON の話をしないためである。
    static func screen(detail: RepoDetail) async throws -> InspectableView<ViewType.ClassifiedView> {
        let repository = StubRepoRepository()
        await repository.setDetailResult(.success(detail))
        let favorites = FavoriteRepositoryImpl(store: InMemoryKeyValueStore())
        let viewModel = RepoDetailViewModel(
            ownerLogin: detail.summary.owner.login,
            repoName: detail.summary.name,
            initialDisplay: nil,
            fetchRepoDetail: FetchRepoDetailUseCase(repository: repository),
            toggleFavorite: ToggleFavoriteUseCase(repository: favorites),
            observeFavoriteIDs: ObserveFavoriteIDsUseCase(repository: favorites),
            now: { RepoDetailViewModelTests.now }
        )
        viewModel.onAppear()
        await waitUntilOnMain { if case .loaded = viewModel.state.phase { true } else { false } }

        return try RepoDetailScreen(makeViewModel: { viewModel }, onOpenURL: { _ in }).inspect()
    }
}

/// クロージャが受け取った値を持ち帰るための入れ物。
@MainActor
final class Box<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
