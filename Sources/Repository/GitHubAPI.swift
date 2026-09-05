import Core
import Foundation

/// GitHub API の定数。**ここに書いていない場所は叩かない**（docs/02-github-api.md §2-3）。
enum GitHubAPI {
    static let baseURL: URL = {
        guard let url = URL(string: "https://api.github.com") else {
            // 固定文字列なので実行時には起きない。黙って別の URL へ倒すと、
            // どこへ通信しているか分からなくなるため、フォールバックは置かない。
            preconditionFailure("GitHub API の baseURL が壊れている")
        }
        return url
    }()

    static let perPage = 30
    /// Search API は 1,000 件を超えて返さない。超えて要求すると 422 になる。
    static let searchResultLimit = 1000

    static func headers(token: String?) -> [String: String] {
        var headers = [
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            // User-Agent が無いと 403 が返る。
            "User-Agent": "GitHubSample/1.0",
        ]
        // 空の Authorization を送ると 401 になるので、無いときはヘッダごと付けない。
        if let token, !token.isEmpty {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
}
