import DesignSystem
import Domain
import Foundation
import Presentation
import Testing

@Suite("Domain と表示への変換")
struct DomainTests {
    @Test("空・空白だけの検索語は作れない", arguments: ["", " ", "\n", "  \t "])
    func rejectsBlankQuery(text: String) {
        #expect(SearchQuery(text) == nil)
    }

    @Test("前後の空白は取り除かれる")
    func trimsQuery() {
        #expect(SearchQuery("  swift  ")?.rawValue == "swift")
    }

    @Test("GitHubError から画面の失敗への対応づけ")
    func mapsErrorsToState() {
        let now = Date(timeIntervalSince1970: 1_000_000)

        #expect(GitHubErrorPresenter.errorState(for: GitHubError.offline, now: now) == .offline)
        #expect(GitHubErrorPresenter.errorState(for: GitHubError.timeout, now: now) == .timeout)
        #expect(GitHubErrorPresenter.errorState(for: GitHubError.notFound, now: now) == .notFound)
        #expect(GitHubErrorPresenter.errorState(for: GitHubError.server(status: 500), now: now) == .generic)
        #expect(GitHubErrorPresenter.errorState(for: GitHubError.decoding, now: now) == .generic)
        #expect(GitHubErrorPresenter.errorState(for: GitHubError.unauthorized, now: now) == .unauthorized)
    }

    @Test("レート制限は resetAt があれば分数を出し、無ければ出さない")
    func mapsRateLimited() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let withReset = GitHubErrorPresenter.errorState(
            for: GitHubError.rateLimited(resetAt: now.addingTimeInterval(300)),
            now: now
        )
        let withoutReset = GitHubErrorPresenter.errorState(for: GitHubError.rateLimited(resetAt: nil), now: now)

        #expect(withReset.message.contains("5 分"))
        #expect(withoutReset.message == "しばらく待ってからお試しください")
        #expect(!withReset.isRetryable)
        #expect(!withoutReset.isRetryable)
    }

    @Test("キャンセルは失敗として扱わない")
    func detectsCancellation() {
        #expect(GitHubErrorPresenter.isCancellation(CancellationError()))
        #expect(GitHubErrorPresenter.isCancellation(URLError(.cancelled)))
        #expect(!GitHubErrorPresenter.isCancellation(URLError(.timedOut)))
        #expect(!GitHubErrorPresenter.isCancellation(GitHubError.offline))
    }

    @Test("表示用の値へ変換し、そこから Entity へ戻しても件数が失われない")
    func roundTripsThroughDisplay() {
        let now = Date(timeIntervalSince1970: 1_756_000_000)
        let original = RepoSummary.stubForDomainTest()

        let display = RepoDisplayMapper.display(for: original, isFavorite: true, now: now)
        let restored = RepoDisplayMapper.summary(from: display)

        #expect(display.starsText == "67.0k")
        #expect(display.isFavorite)
        #expect(restored == original)
    }
}

extension RepoSummary {
    /// TestSupport は Domain より上の層を知っているので、Domain のテストでは使わない。
    static func stubForDomainTest() -> RepoSummary {
        RepoSummary(
            id: RepoID(1),
            name: "swift",
            fullName: "apple/swift",
            owner: Owner(login: "apple", avatarURL: URL(string: "https://example.com/a.png")),
            description: "The Swift Programming Language",
            htmlURL: URL(string: "https://github.com/apple/swift"),
            stars: 67000,
            forks: 10200,
            language: "C++",
            updatedAt: Date(timeIntervalSince1970: 1_755_000_000)
        )
    }
}
