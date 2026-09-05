import Foundation

public struct Owner: Sendable, Equatable {
    public let login: String
    public let avatarURL: URL?

    public init(login: String, avatarURL: URL?) {
        self.login = login
        self.avatarURL = avatarURL
    }
}
