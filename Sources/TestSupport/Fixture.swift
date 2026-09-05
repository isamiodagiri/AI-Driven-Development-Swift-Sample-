import Core
import Foundation

/// 実 API の応答をそのまま切り出した JSON を読む。
///
/// 手で書いたサンプルではなく実応答を使うのは、手書きは「自分が想定した形」しか含まず、
/// `license: null` のような**実際に来る形**を落とすためである（docs/02-github-api.md §6）。
public enum Fixture {
    public static func data(_ name: String) -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
              let data = try? Data(contentsOf: url)
        else {
            preconditionFailure("フィクスチャが見つからない: \(name).json")
        }
        return data
    }

    public static func response(
        _ name: String,
        statusCode: Int = 200,
        headers: [String: String] = [:]
    ) -> HTTPResponse {
        HTTPResponse(statusCode: statusCode, headers: headers, body: data(name))
    }

    public static func emptyResponse(statusCode: Int, headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(statusCode: statusCode, headers: headers, body: Data())
    }
}
