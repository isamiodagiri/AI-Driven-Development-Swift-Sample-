import Foundation

/// クエリ1件。`URLQueryItem` を使わないのは、値型として `Sendable` / `Equatable` を
/// 自前で担保したいため（テストで組み立てた要求をそのまま比較する）。
public struct QueryItem: Sendable, Equatable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

/// 層をまたぐ「要求」の表現。GitHub の知識は持たない。
public struct HTTPRequest: Sendable, Equatable {
    public let url: URL
    public let queryItems: [QueryItem]
    public let headers: [String: String]

    public init(url: URL, queryItems: [QueryItem] = [], headers: [String: String] = [:]) {
        self.url = url
        self.queryItems = queryItems
        self.headers = headers
    }
}
