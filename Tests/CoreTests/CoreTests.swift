import Foundation
import Testing

@testable import Core

@Suite("Core: HTTP と整形")
struct CoreTests {
    @Test("応答ヘッダのキーは小文字に正規化される")
    func normalizesHeaderKeys() {
        let response = HTTPResponse(statusCode: 200, headers: ["X-RateLimit-Remaining": "0"])

        #expect(response.header("x-ratelimit-remaining") == "0")
        #expect(response.header("X-RATELIMIT-REMAINING") == "0")
    }

    @Test("1,000 以上は k 表記に丸める", arguments: [
        (0, "0"), (1, "1"), (999, "999"), (1000, "1.0k"), (1500, "1.5k"), (67000, "67.0k"),
    ])
    func formatsCompactCount(value: Int, expected: String) {
        #expect(CountText.compact(value) == expected)
    }

    @Test("7日以内は相対表記、それ以降は日付")
    func formatsRelativeDate() {
        let now = Date(timeIntervalSince1970: 1_756_000_000)

        #expect(RelativeDateText.text(for: now.addingTimeInterval(-30), now: now) == "たった今")
        #expect(RelativeDateText.text(for: now.addingTimeInterval(-600), now: now) == "10分前")
        #expect(RelativeDateText.text(for: now.addingTimeInterval(-7200), now: now) == "2時間前")
        #expect(RelativeDateText.text(for: now.addingTimeInterval(-3 * 86400), now: now) == "3日前")
        #expect(RelativeDateText.text(for: now.addingTimeInterval(-30 * 86400), now: now).contains("/"))
    }

    @Test("レート制限の残り分数は切り上げる（あと0分と出さない）")
    func roundsUpMinutes() {
        let now = Date(timeIntervalSince1970: 1_000_000)

        #expect(RelativeDateText.minutesUntil(now.addingTimeInterval(1), from: now) == 1)
        #expect(RelativeDateText.minutesUntil(now.addingTimeInterval(180), from: now) == 3)
        #expect(RelativeDateText.minutesUntil(now.addingTimeInterval(-10), from: now) == 0)
    }
}
