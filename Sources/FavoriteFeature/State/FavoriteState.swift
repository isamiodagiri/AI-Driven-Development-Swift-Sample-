import DesignSystem

public enum FavoritePhase: Sendable, Equatable {
    case loading
    case empty
    case loaded(rows: [RepoRowDisplay])
}

public struct FavoriteState: Sendable, Equatable {
    public var phase: FavoritePhase

    public init(phase: FavoritePhase = .loading) {
        self.phase = phase
    }
}
