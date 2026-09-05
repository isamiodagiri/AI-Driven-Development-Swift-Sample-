import DesignSystem
import Foundation
import Presentation
import SwiftUI
import Testing
import TestSupport
import ViewInspector

@testable import SearchFeature

/// UC-001 の View 層（TS-48〜TS-53）。
///
/// 狙いは1つだけである — **State に出ているのに画面に出ていない**を見つけること
/// （[04 §3](../../docs/04-test-strategy.md)）。レイアウトそのものは見ない。
/// 観測は `AppIdentifier` の識別子で行う（テストと View が同じ定数を見る）。
@MainActor
@Suite("UC-001 View: 検索")
struct SearchScreenViewTests {
    @Test("TS-48 loading のときスケルトンが6行出る")
    func showsSixSkeletonRowsWhileLoading() async throws {
        let sut = SearchFixture.makeSUT()
        await sut.client.set(
            .success(Fixture.response("search_repositories_ok")),
            forQuery: "swift",
            manualRelease: true
        )
        sut.viewModel.query = "swift"
        await waitUntilOnMain { sut.viewModel.displayState.phase == .loading }

        let screen = SearchScreen(makeViewModel: { sut.viewModel }, onSelectRepo: { _ in })
        let rows = try screen.inspect().findAll(where: {
            (try? $0.accessibilityIdentifier()) == AppIdentifier.skeletonRow
        })

        #expect(rows.count == 6)
    }

    @Test("TS-53 initial のとき案内文が出る")
    func showsGuidanceWhenInitial() throws {
        let sut = SearchFixture.makeSUT()
        #expect(sut.viewModel.displayState.phase == .initial)

        let screen = SearchScreen(makeViewModel: { sut.viewModel }, onSelectRepo: { _ in })

        #expect(throws: Never.self) {
            try screen.inspect().find(viewWithAccessibilityIdentifier: AppIdentifier.emptyView)
        }
    }

    @Test("TS-51 行をタップすると onSelectRepo が、その行の display 付きで呼ばれる")
    func callsOnSelectRepoWithTappedRow() async throws {
        let sut = await SearchFixture.loadedSUT()
        let selected = Box<RepoRowDisplay?>(nil)

        let screen = SearchScreen(makeViewModel: { sut.viewModel }, onSelectRepo: { selected.value = $0 })
        // タップの結線は行部品そのものに付いている（識別子は部品の内側にある）
        let row = try screen.inspect().find(AppRepoRow.self)
        try row.callOnTapGesture()

        let expected = SearchFixture.rows(sut.viewModel.displayState.phase).first?.display
        #expect(selected.value?.id == expected?.id)
    }

    @Test("TS-49 説明が nil の行には、説明の Text が無い")
    func omitsDescriptionWhenNil() throws {
        let withText = AppRepoRow(display: Self.display(description: "説明がある"), onToggleFavorite: {})
        let withoutText = AppRepoRow(display: Self.display(description: nil), onToggleFavorite: {})

        #expect(throws: Never.self) {
            try withText.inspect().find(viewWithAccessibilityIdentifier: AppIdentifier.repoRowDescription)
        }
        // 「出ない」ほうが本題である。State だけでは観測できない（04 §3）
        #expect(throws: (any Error).self) {
            try withoutText.inspect().find(viewWithAccessibilityIdentifier: AppIdentifier.repoRowDescription)
        }
    }

    @Test("TS-50 言語が nil の行には、言語の表示が無い")
    func omitsLanguageWhenNil() throws {
        let withLanguage = AppRepoRow(display: Self.display(language: "Swift"), onToggleFavorite: {})
        let withoutLanguage = AppRepoRow(display: Self.display(language: nil), onToggleFavorite: {})

        #expect(throws: Never.self) {
            try withLanguage.inspect().find(viewWithAccessibilityIdentifier: AppIdentifier.repoRowLanguage)
        }
        #expect(throws: (any Error).self) {
            try withoutLanguage.inspect().find(viewWithAccessibilityIdentifier: AppIdentifier.repoRowLanguage)
        }
    }

    @Test("TS-52 ☆ を押すと onToggleFavorite が呼ばれる")
    func callsToggleFavoriteOnStarTap() throws {
        let tapped = Box(0)
        let row = AppRepoRow(display: Self.display(), onToggleFavorite: { tapped.value += 1 })

        let button = try row.inspect().find(viewWithAccessibilityIdentifier: AppIdentifier.repoRowFavoriteButton)
        try button.button().tap()

        #expect(tapped.value == 1)
    }

    @Test("TS-101 ☆ / ★ のボタンには、状態に応じた読み上げ名が付く")
    func starButtonHasAccessibilityLabel() throws {
        let notFavorite = AppRepoRow(display: Self.display(isFavorite: false), onToggleFavorite: {})
        let favorite = AppRepoRow(display: Self.display(isFavorite: true), onToggleFavorite: {})

        // アイコンだけのボタンは、ラベルが無いと VoiceOver で「ボタン」としか読まれない（裁定 D-19）
        #expect(try Self.label(of: AppIdentifier.repoRowFavoriteButton, in: notFavorite) == "お気に入りに追加")
        #expect(try Self.label(of: AppIdentifier.repoRowFavoriteButton, in: favorite) == "お気に入りから外す")
    }

    // MARK: - 補助

    static func label(of identifier: String, in view: some View) throws -> String {
        try view.inspect()
            .find(viewWithAccessibilityIdentifier: identifier)
            .accessibilityLabel()
            .string()
    }

    /// 変換そのものは Presentation の仕事なので、テストでも同じ道を通す。
    static func display(
        description: String? = "説明",
        language: String? = "Swift",
        isFavorite: Bool = false
    ) -> RepoRowDisplay {
        RepoDisplayMapper.display(
            for: .stub(description: description, language: language),
            isFavorite: isFavorite,
            now: SearchFixture.now
        )
    }
}

/// クロージャが受け取った値を持ち帰るための入れ物。
/// テストは `@MainActor` なので、これ以上の保護は要らない。
@MainActor
final class Box<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
