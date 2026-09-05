import Foundation

/// `URLSession` を触ってよい唯一の場所（INV-3）。
///
/// 保持しているのは `let` の `URLSession` だけなので、`@unchecked` を付けずに `Sendable` である。
public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
        if !request.queryItems.isEmpty {
            components?.queryItems = request.queryItems.map { URLQueryItem(name: $0.name, value: $0.value) }
        }
        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var urlRequest = URLRequest(url: url)
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        // キャンセルされたときは URLError.cancelled が投げられる。ここでは握りつぶさず、
        // そのまま上へ流す（写像するのは Repository、握りつぶすのは ViewModel。docs/01 §5-4）。
        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }
        return HTTPResponse(statusCode: http.statusCode, headers: headers, body: data)
    }
}
