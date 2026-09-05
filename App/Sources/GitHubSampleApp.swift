import AppComposition
import SwiftUI

@main
struct GitHubSampleApp: App {
    /// 合成ルートはここで1つだけ作る。以後は誰も差し替えない。
    ///
    /// トークンは任意である。無ければ未認証で動く（検索 10 回/分・その他 60 回/時）。
    /// **バンドルに埋めたトークンは取り出せるので、配布するアプリでこの方式を採ってはならない**
    /// （docs/02-github-api.md §5）。
    @State private var dependencies = CompositionRoot.live(token: CompositionRoot.tokenFromBundle())

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: dependencies)
        }
    }
}
