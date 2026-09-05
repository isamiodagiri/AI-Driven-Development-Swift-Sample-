import Core
import DesignSystem
import Domain
import Foundation

/// Entity → 表示用の値への変換と、その逆。
///
/// 3つの Feature が同じ行を描くので、変換もここに1つだけ置く
/// （Feature 同士は参照できないため、共有できる場所はここしかない ＝ INV-2）。
public enum RepoDisplayMapper {
    public static func display(for summary: RepoSummary, isFavorite: Bool, now: Date) -> RepoRowDisplay {
        RepoRowDisplay(
            id: summary.id.rawValue,
            ownerLogin: summary.owner.login,
            name: summary.name,
            fullName: summary.fullName,
            avatarURL: summary.owner.avatarURL,
            htmlURL: summary.htmlURL,
            description: summary.description,
            stars: summary.stars,
            forks: summary.forks,
            starsText: CountText.compact(summary.stars),
            forksText: CountText.compact(summary.forks),
            language: summary.language,
            updatedAt: summary.updatedAt,
            updatedText: RelativeDateText.text(for: summary.updatedAt, now: now),
            isFavorite: isFavorite
        )
    }

    /// 表示用の値から Entity へ戻す。
    ///
    /// 詳細の取得に失敗した画面から、お気に入りへ保存するときに使う（UC-002 AC-20・AC-21）。
    /// **素の値を持たせてあるので、件数が 0 に化けることはない。**
    public static func summary(from display: RepoRowDisplay) -> RepoSummary {
        RepoSummary(
            id: RepoID(display.id),
            name: display.name,
            fullName: display.fullName,
            owner: Owner(login: display.ownerLogin, avatarURL: display.avatarURL),
            description: display.description,
            htmlURL: display.htmlURL,
            stars: display.stars,
            forks: display.forks,
            language: display.language,
            updatedAt: display.updatedAt
        )
    }
}
