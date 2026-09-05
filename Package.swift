// swift-tools-version: 6.0
import PackageDescription

// 層依存はこのファイルの `dependencies` が唯一の強制手段である（INV-1・INV-2）。
// Feature に Repository を書き足すと層の飛び越しが通ってしまうので、増やすときは
// docs/01-architecture.md §3 を読んでからにすること。
let package = Package(
    name: "GitHubSample",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AppComposition", targets: ["AppComposition"]),
    ],
    // テスト専用の依存を1つだけ入れている（裁定 D-18）。
    // Sources/ のどのターゲットからも見えない — Feature のテストにだけ書いてあるため。
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.3"),
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "Domain", dependencies: ["Core"]),
        .target(name: "Repository", dependencies: ["Domain", "Core"]),
        .target(name: "UseCase", dependencies: ["Repository", "Domain", "Core"]),
        .target(name: "DesignSystem", dependencies: ["Core"]),

        // Entity → 表示用の値への変換と、失敗の対応づけ。3つの Feature が共有する
        // （Feature 同士は参照できないので、共有できる場所はここしかない）。
        .target(name: "Presentation", dependencies: ["Domain", "DesignSystem", "Core"]),

        // Feature 同士は依存に書かない（INV-2）。Domain は ViewModel の変換のためだけに要る。
        .target(name: "SearchFeature", dependencies: ["UseCase", "Domain", "Presentation", "DesignSystem", "Core"]),
        .target(name: "RepoDetailFeature", dependencies: ["UseCase", "Domain", "Presentation", "DesignSystem", "Core"]),
        .target(name: "FavoriteFeature", dependencies: ["UseCase", "Domain", "Presentation", "DesignSystem", "Core"]),

        // 合成ルート。ここだけが全 Feature を知ってよい。
        .target(
            name: "AppComposition",
            dependencies: [
                "SearchFeature",
                "RepoDetailFeature",
                "FavoriteFeature",
                "UseCase",
                "Repository",
                "Domain",
                "Presentation",
                "DesignSystem",
                "Core",
            ]
        ),

        .target(name: "TestSupport", dependencies: ["Repository", "Domain", "Core"], resources: [.copy("Fixtures")]),

        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain", "Presentation", "DesignSystem"]),
        .testTarget(name: "RepositoryTests", dependencies: ["Repository", "TestSupport", "Domain", "Core"]),
        .testTarget(name: "UseCaseTests", dependencies: ["UseCase", "TestSupport", "Repository", "Domain"]),
        .testTarget(
            name: "SearchFeatureTests",
            dependencies: [
                .product(name: "ViewInspector", package: "ViewInspector"),
                "SearchFeature",
                "TestSupport",
                "Repository",
                "UseCase",
                "Presentation",
                "DesignSystem",
                "Domain",
                "Core",
            ]
        ),
        .testTarget(
            name: "RepoDetailFeatureTests",
            dependencies: [
                .product(name: "ViewInspector", package: "ViewInspector"),
                "RepoDetailFeature",
                "TestSupport",
                "Repository",
                "UseCase",
                "Presentation",
                "DesignSystem",
                "Domain",
                "Core",
            ]
        ),
        .testTarget(
            name: "FavoriteFeatureTests",
            dependencies: [
                .product(name: "ViewInspector", package: "ViewInspector"),
                "FavoriteFeature",
                "SearchFeature",
                "RepoDetailFeature",
                "TestSupport",
                "Repository",
                "UseCase",
                "Presentation",
                "DesignSystem",
                "Domain",
                "Core",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
