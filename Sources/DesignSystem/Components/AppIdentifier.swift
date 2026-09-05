/// テストが要素を掴むための識別子。**テストと View の両方がここを見る**ので、
/// 文字列を直接書かない（改名しても両方が同時に追随する）。
public enum AppIdentifier {
    public static let skeletonRow = "app.skeleton.row"
    public static let emptyView = "app.empty"
    public static let errorView = "app.error"
    public static let errorRetryButton = "app.error.retry"
    public static let repoRow = "app.repo.row"
    public static let repoRowDescription = "app.repo.row.description"
    public static let repoRowLanguage = "app.repo.row.language"
    public static let repoRowFavoriteButton = "app.repo.row.favorite"
    public static let footerSpinner = "app.footer.spinner"
    public static let detailLicense = "app.detail.license"
    public static let detailTopics = "app.detail.topics"
    public static let detailArchivedBadge = "app.detail.archived"
    public static let detailForkBadge = "app.detail.fork"
    public static let detailOpenInBrowser = "app.detail.open"
    public static let detailPartialError = "app.detail.partialError"
}
