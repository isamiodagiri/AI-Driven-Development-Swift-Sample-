# 01 アーキテクチャ設計

> **正**: モジュール構成・層依存・Concurrency と Combine の分担・命名規約・DI。
> 実装コードとこの文書が食い違ったら、**まずこの文書が正**として実装を直す。
> 設計として誤っていた場合は、**この文書を直してから**実装を直す（コードだけ直して放置しない）。

---

## 1. 全体像

```
┌─────────────────────────────────────────────────────────────┐
│ App（Xcode プロジェクト。合成ルート）                          │
│  ・DI の結線／NavigationStack の path 所有／画面遷移の結線      │
└───────────────┬─────────────────────────────────────────────┘
                │ 生成・注入
   ┌────────────┴───────────┬────────────────────┐
   ▼                        ▼                    ▼
┌──────────────┐  ┌──────────────────┐  ┌────────────────┐
│ SearchFeature│  │ RepoDetailFeature│  │ FavoriteFeature│  ← View / ViewModel
└──────┬───────┘  └────────┬─────────┘  └───────┬────────┘
       └──────────┬────────┴───────────┬────────┘
                  ▼                    ▼
            ┌──────────┐        ┌───────────────┐
            │ UseCase  │        │ DesignSystem  │（Feature からのみ参照）
            └────┬─────┘        └───────────────┘
                 ▼
            ┌────────────┐
            │ Repository │  ← ここだけが URLSession / UserDefaults を触る
            └────┬───────┘
                 ▼
            ┌──────────┐
            │  Domain  │  ← Entity・値オブジェクト・ドメインエラー
            └────┬─────┘
                 ▼
            ┌──────────┐
            │   Core   │  ← HTTP の原始的な道具・ログ・拡張
            └──────────┘
```

**依存は内向きの一方向のみ**。`Feature → UseCase → Repository → Domain → Core`。
逆流（Domain が Repository を知る等）と飛び越し（Feature が Repository を直接使う等）は
**SPM のターゲット依存に無いのでコンパイルが通らない**。

---

## 2. リポジトリ構成

```
GitHubSample/
  AGENTS.md                     # 開発規約（コマンド・ディレクトリ・レビュー手順）
  Package.swift                 # ローカル Swift Package（全ターゲットを定義）
  Sources/
    Core/                       # 依存なし
      HTTP/                     #   HTTPClient（protocol）・URLSessionHTTPClient・HTTPRequest/Response
      Log/                      #   AppLogger（os.Logger の薄い包み）
      Extensions/
    Domain/                     # → Core
      Entity/                   #   Repo, RepoSummary, RepoDetail, Owner, License, Topic
      ValueObject/              #   RepoID, SearchQuery, PageIndex, StarCount
      Error/                    #   GitHubError
    Repository/                 # → Domain, Core
      RepoRepository/           #   protocol + Impl（GitHub API）
      FavoriteRepository/       #   protocol + Impl（UserDefaults）
      DTO/                      #   API の JSON に1対1で対応する Decodable（外へ出さない）
    UseCase/                    # → Repository, Domain, Core
      SearchReposUseCase.swift
      LoadMoreReposUseCase.swift
      FetchRepoDetailUseCase.swift
      ToggleFavoriteUseCase.swift
      ObserveFavoriteIDsUseCase.swift
      ListFavoriteReposUseCase.swift
    DesignSystem/               # → Core のみ（業務層を知らない）
      Tokens/                   #   AppColor, AppSpacing, AppTypography, AppRadius, AppSize
      Components/               #   AppRepoRow, AppErrorView, AppEmptyView, AppSkeletonRow,
                                #   AppStatBadge, AppFooterSpinner, RepoRowDisplay, AppErrorState
    Presentation/               # → Domain, DesignSystem, Core
                                #   RepoDisplayMapper（Entity ⇄ 表示用の値）
                                #   GitHubErrorPresenter（GitHubError → 画面の失敗）
    SearchFeature/              # → UseCase, DesignSystem, Core（+ Domain: ViewModel のみ）
      View/  ViewModel/  State/
    RepoDetailFeature/          # 同上
    FavoriteFeature/            # 同上
    AppComposition/             # 合成ルート。ここだけが全 Feature を知ってよい
      CompositionRoot.swift  AppRootView.swift
    TestSupport/                # → Repository, Domain, Core（テストからのみ参照）
      StubHTTPClient.swift  StubRepoRepository.swift  InMemoryKeyValueStore.swift
      Builders.swift  Fixture.swift  Waiting.swift  Fixtures/*.json
  Tests/
    CoreTests/ DomainTests/ RepositoryTests/ UseCaseTests/
    SearchFeatureTests/ RepoDetailFeatureTests/ FavoriteFeatureTests/
  App/                          # 薄いアプリシェル（Xcode プロジェクトは手作業で作る。App/README.md）
  .swiftlint.yml                # SwiftLint 設定。custom_rules が INV-3〜INV-13 を強制する
  scripts/
    test-lint-rules.sh          # custom_rules そのものの検収（違反注入。§9-4）
    swiftlint_sim.py            #   SwiftLint が無い環境での代替チェッカー（§9-4）
  docs/                         # 本設計書群
  .github/workflows/ci.yml
```

### 2-1. なぜアプリ本体が Xcode プロジェクトなのか

iOS アプリのバンドルは SwiftPM だけでは作れない。一方で **`swift test` が Xcode 無しで回る**ことは
CI の速度と安定に効くため、**画面・ロジックはすべて Package 側に置き、Xcode プロジェクトは
「起動して合成するだけ」の空に近い殻**にする。`Package.swift` の platforms に `.macOS(.v14)` も含め、
CI の単体テストは macOS 上で `swift test` 一発で走らせる（UI スナップショットのみ iOS シミュレータ）。

---

## 3. 層の規約

### 3-1. 各層の責務

| 層 | 置くもの | 置かないもの |
|---|---|---|
| **Core** | HTTP の下回り（`HTTPClient` protocol と URLSession 実装）・ログ・汎用拡張 | GitHub の知識、業務の言葉（`Repo` を知らない） |
| **Domain** | Entity・値オブジェクト・`GitHubError`・純粋な判定 | I/O、`Codable` の API 対応（DTO は Repository 層） |
| **Repository** | データアクセスの単一窓口。DTO → Entity 変換、HTTP ステータス → `GitHubError` 変換、ページング状態の解釈 | 業務手順の組み立て、UI 文言、**他の Repository**（INV-13） |
| **UseCase** | ViewModel と Repository の間。**複数 Repository をまたぐ手順**と入力の検証 | 保持する状態、UI 文言、**他の UseCase**（INV-12） |
| **Feature/ViewModel** | 画面の状態機械。Entity → State 変換、Combine による入力の合成、Task のキャンセル | HTTP、永続化、**他の ViewModel**（INV-11） |
| **Feature/View** | SwiftUI の宣言のみ。**参照する ViewModel は1つだけ**（INV-9） | **ロジック**（INV-10）、Entity 参照、色・数値の直書き、UseCase / Repository |
| **Feature/State** | 画面が描くのに必要な値だけを持つ `struct`（`Equatable`, `Sendable`） | **ロジック（メソッド・計算プロパティでの判断）** |
| **DesignSystem** | トークンと共通部品。**View が持てない実色・実数値の置き場** | 業務層への依存 |
| **Presentation** | Entity → 表示用の値への変換と、失敗の対応づけ。**3つの Feature が共有する** | 状態、I/O、UseCase への依存 |

### 3-2. Feature を画面ごとに分けた理由（ChildAsset 方式を採る）

kotoba-album は `feature` 1パッケージ、ChildAsset は `*_feature` 複数パッケージである。
本PJは **ChildAsset 方式（画面ごとに別ターゲット）** を採る。理由は
**「Feature 同士を参照しない」を人ではなくコンパイラに守らせられる**のは分割した場合だけであるため。
1ターゲットにまとめると、この規約は grep 検査に落ちる（＝ INV-2 が INV-3 と同じ弱さになる）。

### 3-3. View / State から Entity を参照しない

ViewModel が `RepoSummary`（Domain）→ `RepoRowState`（Feature）へ変換し、View と State は
Feature 内の型しか知らない。**この規約はターゲット分割では落とせない**（ViewModel が同じターゲットに居るため
Domain への依存が必要）ので、**SwiftLint のカスタムルール** `inv5_domain_in_view_or_state` が
`Sources/*Feature/{View,State}/**` に `import Domain` が無いことを検査する（§9）。

> **なぜ守るか**: 参照元2PJで実測された効果は「API の都合で Entity が変わったとき、
> 壊れる場所が ViewModel の変換関数1箇所に閉じる」こと。View まで Entity を見ていると、
> 画面の数だけ壊れる。

### 3-4. 画面遷移

Feature 同士が参照できないので、**遷移は Feature が公開するクロージャで外へ出し、App が結線する**。

```swift
// SearchFeature
public struct SearchScreen: View {
    @StateObject private var viewModel: SearchViewModel
    private let onSelectRepo: @MainActor (RepoIDValue) -> Void   // ← App が渡す
}
```

`NavigationStack` の `path` は App 層が持つ。Feature は「押された」しか言わない。

### 3-5. 同じ層のもの同士を参照しない（INV-9〜INV-13）

層の**縦**（Feature → UseCase → …）は SPM が守る。**横**（同じ層の中）は同一ターゲット内なので
コンパイラに見えない。**SwiftLint の `custom_rules`** が守る（§9）。

| ルール | 何が壊れるのを防ぐか | 代わりにどうするか |
|---|---|---|
| **View が参照する ViewModel は1つ**（INV-9） | 画面の状態が複数の持ち主に分かれ、**どちらが真実源か決まらなくなる** | 子 View には**値（State）とクロージャ**を渡す。ViewModel を渡さない |
| **View は UseCase / Repository を参照しない**（INV-9） | 層の飛び越し。同一ターゲット内なので SPM では落ちない | ViewModel 経由で呼ぶ |
| **View はロジックを持たない**（INV-10） | 表示の加工が View に散り、**テストできない場所に判断が入る** | 整形・並べ替え・非同期・例外処理は ViewModel。View は State を描くだけ |
| **ViewModel は他の ViewModel を参照しない**（INV-11） | 画面間の依存。片方の寿命が切れたときに、もう片方が壊れる | 共有したい状態は **Repository を真実源にして両方が購読**する（UC-003 がその形） |
| **UseCase は他の UseCase を参照しない**（INV-12） | 手順の起点が分からなくなり、**同じ処理が二重に走る**経路ができる | 合成が要るなら**1つの UseCase の中で** Repository を並べる。画面都合の合成は ViewModel |
| **Repository は他の Repository を参照しない**（INV-13） | データ源をまたぐ手順が Repository に沈み、**UseCase を通らない経路**ができる | またぐ手順は UseCase の仕事 |

> **INV-11 の実例**: 「検索画面のお気に入り状態」を `FavoriteViewModel` から取りたくなるが、
> それをやると検索画面が お気に入り画面の生存に依存する。
> 正しくは `FavoriteRepository`（actor）の `AsyncStream` を**両方が独立に購読**する
> （[03 §C-2](03-screens.md)）。**このルールが UC-003 の設計を決めている。**

---

## 4. 命名規約（判定の根拠になるので崩さない）

| 対象 | 規約 | 例 |
|---|---|---|
| ターゲット | 層名そのまま／Feature は `<画面>Feature` | `UseCase`, `SearchFeature` |
| Repository | protocol は `<名詞>Repository`、実装は `<名詞>RepositoryImpl` | `RepoRepository` / `RepoRepositoryImpl` |
| UseCase | `<動詞><目的語>UseCase`。**1つの `callAsFunction`** だけを公開する | `SearchReposUseCase` |
| ViewModel | `<画面>ViewModel`。`@MainActor final class`、`ObservableObject` 準拠 | `SearchViewModel` |
| View | `<画面>Screen`（画面全体）／`<部品>View`（部品） | `SearchScreen`, `RepoRowView` |
| State | `<画面>State` / `<行>RowState`。`struct` で `Equatable, Sendable` | `SearchState` |
| DTO | `<API名>DTO`。**Repository ターゲットの外へ出さない**（`internal`） | `RepoSearchResponseDTO` |
| DesignSystem | トークンは `App*`、部品も `App*` | `AppColor.textPrimary`, `AppErrorView` |

> **「Repository」という語の衝突について**: GitHub の "repository"（＝ Entity）と、層としての Repository が
> 同じ語になる。**Entity 側を `Repo` に短縮**して回避する（`Repo`, `RepoSummary`, `RepoDetail`）。
> `RepoRepository` は読みにくいが、**層の名前を曲げるより Entity を短くするほうが規約が壊れにくい**
> と判断した（裁定 D-2）。

---

## 5. 並行性（Swift Concurrency）と Combine の分担 ★本PJの中核

### 5-1. 決めたこと

> **境界（Repository / UseCase）は `async/await`。出力（ViewModel → View）は Combine。**

| 位置 | 使うもの | 理由 |
|---|---|---|
| Repository の1回きりの取得 | `func search(...) async throws -> Page<RepoSummary>` | キャンセルが構造化されている。`URLSession` の async API がそのまま乗る |
| Repository の変化の通知（お気に入り） | `func favoriteIDStream() -> AsyncStream<Set<RepoID>>` | actor が持つ状態を安全に外へ流せる。`Publisher` は `Sendable` 境界の扱いが煩雑 |
| UseCase | `async throws`（`Sendable` な `struct`） | 上に同じ |
| ViewModel の入力合成 | **Combine**（`debounce` / `removeDuplicates` / `CombineLatest`） | 時間軸の合成は Combine のほうが素直に書ける |
| ViewModel → View | **Combine**（`ObservableObject` + `@Published`） | SwiftUI の標準の出力経路 |

**AsyncStream を ViewModel が読むところで Combine の世界に入る**。境界は1箇所（`@MainActor` の ViewModel）に閉じる。

```swift
@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""                        // View → ViewModel（入力）
    @Published private(set) var state: SearchState = .initial // ViewModel → View（出力）
    @Published private(set) var favoriteIDs: Set<Int> = []    // AsyncStream から流し込む

    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    func onAppear() {
        // ① 入力の debounce（Combine）
        $query
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] text in self?.startSearch(text) }
            .store(in: &cancellables)

        // ② お気に入りの購読（AsyncStream → @Published）。ViewModel が唯一の変換点
        Task { [weak self] in
            guard let stream = self?.observeFavoriteIDs() else { return }
            for await ids in stream { self?.favoriteIDs = ids }
        }

        // ③ 派生状態の合成（Combine）
        Publishers.CombineLatest($state, $favoriteIDs)
            .map(SearchState.applyingFavorites)   // 純粋関数。State はロジックを持たない
            .assign(to: &$displayState)
    }

    private func startSearch(_ text: String) {
        searchTask?.cancel()                       // ④ 前の検索を必ず捨てる
        searchTask = Task { [weak self] in
            // ... await searchRepos(query:) ...
            // Task.isCancelled / CancellationError はユーザー向けエラーにしない
        }
    }
}
```

### 5-2. 採らなかった案

- **全層 Combine（Repository が `AnyPublisher` を返す）**
  → キャンセルの伝播が `AnyCancellable` の保持責任に依存し、`Sendable` / actor と噛み合わない。
  Swift 6 の完全チェックでは `Publisher` の値を actor 境界で受け渡すたびに手当てが要る。
  **本PJの評価軸（`@unchecked Sendable` ゼロ）と両立しない**ので採らない。
- **全層 async/await（Combine ゼロ、`@Observable` のみ）**
  → 依頼「SwiftUI の Combine」から外れる。また `debounce` を自前で書くと
  「テストしにくい `Task.sleep`」が増える。

### 5-3. Sendable の方針

| 種別 | 形 | Sendable の担保 |
|---|---|---|
| Entity・値オブジェクト・State | `struct`（全プロパティが値型 / `let`） | 自動 |
| Repository の protocol | `protocol RepoRepository: Sendable` | 準拠を要求する |
| Repository の実装（読み取り専用） | `final class ...: Sendable`（stored はすべて `let`） | 不変で担保 |
| Repository の実装（状態を持つ） | **`actor`**（`FavoriteRepositoryImpl`） | actor 隔離 |
| UseCase | `struct ...: Sendable`（依存を `let` で保持） | 自動 |
| ViewModel | `@MainActor final class` | MainActor 隔離 |
| クロージャ引数（Feature → App） | `@MainActor (…) -> Void` | 呼ぶ側も MainActor |

- **`@unchecked Sendable` と `nonisolated(unsafe)` は書かない**（INV-4）。
  必要になったら「型の設計が誤っている」の合図として扱い、`actor` か `let` へ寄せる
- `Package.swift` で **Swift 6 language mode**（`swiftLanguageMode(.v6)`）を全ターゲットに指定する

### 5-4. キャンセルの規約

1. 検索は打鍵のたびに**前の Task を `cancel()` してから**新しい Task を作る
2. `URLSession` の async API はキャンセルで `URLError.cancelled` を投げる。
   **Repository は `URLError.cancelled` と `CancellationError` を `GitHubError` に写像しない**（そのまま投げる）
3. ViewModel は `CancellationError` / `URLError.cancelled` を捕まえたら**状態を変えない**
   （エラー表示にしない・ローディングも解除しない。後続の Task が状態を持つ）
4. **古い応答が新しい結果を上書きしてはならない**（AC で明示。TS で観測する）。
   `cancel()` だけに頼らず、**リクエストごとの世代番号**を ViewModel が持ち、
   `state` を書く直前に自分が最新であることを確認する

> 3 と 4 は別物である。3 が守られていても、`cancel()` がネットワーク完了直後に呼ばれた場合は
> 応答が返り切っており、世代番号が無いと古い結果が勝つ。**両方要る**。

---

## 6. DI（依存の注入）

**合成ルートは App の `CompositionRoot`** だけ。フレームワークは使わない。

```swift
struct AppDependencies: Sendable {
    let searchRepos: SearchReposUseCase
    let fetchRepoDetail: FetchRepoDetailUseCase
    let toggleFavorite: ToggleFavoriteUseCase
    let observeFavoriteIDs: ObserveFavoriteIDsUseCase
    let listFavoriteRepos: ListFavoriteReposUseCase
}
```

- Repository の実装を差し替えられるのは **`CompositionRoot` の中だけ**
- ViewModel は **protocol ではなく UseCase の具体型**を受け取る
  （UseCase は `struct` で依存が protocol なので、テストは Repository のスタブで足りる。
  UseCase ごとの protocol を作ると、**テストダブルが実物より寛容になる罠**が1段増える）
- SwiftUI の `@EnvironmentObject` は使わない（誰が何に依存しているかがコンパイル時に見えなくなるため）

---

## 7. エラーと状態

### 7-1. ドメインエラー（Domain）

```swift
public enum GitHubError: Error, Equatable, Sendable {
    case offline                       // 通信できない
    case timeout
    case rateLimited(resetAt: Date?)   // 403 + x-ratelimit-remaining: 0
    case unauthorized                  // 401（トークンを付けた場合のみ起こりうる）
    case notFound                      // 404
    case invalidQuery(reason: String)  // 422
    case server(status: Int)           // 5xx
    case decoding                      // 応答の形が違う
    case unknown
}
```

写像の表は [02-github-api.md](02-github-api.md) §4 が正。**Repository が写像し、それより上は `GitHubError` しか見ない**。

### 7-2. 画面の状態

各画面の State は**排他な列挙**を持つ。`isLoading` と `error` と `items` を独立したフラグで持たない
（「ローディング中かつエラー」のような**表現できてはいけない状態**を型で消す）。

```swift
public struct SearchState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case initial                       // 未入力
        case loading                       // 初回検索中（スケルトン）
        case loaded(items: [RepoRowState], hasMore: Bool)
        case loadingMore(items: [RepoRowState])
        case empty(query: String)          // 0件
        case failed(AppErrorState)         // 失敗（再試行できる）
    }
    public var phase: Phase
}
```

**State はロジックを持たない**（メソッド・判断を含む計算プロパティを置かない）。変換は ViewModel の純粋関数で行う。

---

## 8. SPM の定義（骨子）

```swift
// Package.swift（swift-tools-version: 6.0）
let package = Package(
    name: "GitHubSample",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SearchFeature", targets: ["SearchFeature"]),
        .library(name: "RepoDetailFeature", targets: ["RepoDetailFeature"]),
        .library(name: "FavoriteFeature", targets: ["FavoriteFeature"]),
        .library(name: "AppComposition", targets: ["UseCase", "Repository"]),
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "Domain", dependencies: ["Core"]),
        .target(name: "Repository", dependencies: ["Domain", "Core"]),
        .target(name: "UseCase", dependencies: ["Repository", "Domain", "Core"]),
        .target(name: "DesignSystem", dependencies: ["Core"]),
        .target(name: "SearchFeature", dependencies: ["UseCase", "DesignSystem", "Domain"]),
        .target(name: "RepoDetailFeature", dependencies: ["UseCase", "DesignSystem", "Domain"]),
        .target(name: "FavoriteFeature", dependencies: ["UseCase", "DesignSystem", "Domain"]),
        .target(name: "TestSupport", dependencies: ["Domain", "Core"]),
        // Tests...
    ],
    swiftLanguageModes: [.v6]
)
```

**`Feature` の依存に `Repository` が無いこと**が INV-1 の実体である。
`Domain` が入っているのは ViewModel の変換のためで、View / State からの参照は §3-3 の検査が禁じる。

---

## 9. Lint（`.swiftlint.yml` の `custom_rules`）

SPM のターゲット依存で落とせない不変条件は、**SwiftLint のカスタムルール**が強制する。
Xcode に警告として出て、CI では `swiftlint --strict` が exit 1 にする。

```bash
brew install swiftlint          # 導入
swiftlint --strict              # CI と同じ判定（違反 1 件で落ちる）
```

### 9-1. ルール一覧（**この表と `.swiftlint.yml` は同期させる**）

| 不変条件 | ルール名 | 対象パス | 何を見るか |
|---|---|---|---|
| INV-3 | `inv3_urlsession_outside_core_http` | `Core/HTTP/` 以外 | `URLSession` の出現 |
| INV-3 | `inv3_userdefaults_outside_repository` | `Repository/` 以外 | `UserDefaults` の出現 |
| INV-4 | `inv4_unchecked_sendable` | 全体 | `@unchecked Sendable` / `nonisolated(unsafe)` |
| INV-5 | `inv5_domain_in_view_or_state` | `*Feature/View/`, `*Feature/State/` | `import Domain` |
| INV-6 | `inv6_hardcoded_style_in_view` | `*Feature/View/` | `Color(` / `Color.<小文字>` / `.font(.system` / `padding(`・`frame(`・`spacing:`・`top:` 等に**数値リテラル** |
| **INV-9** | `inv9_multiple_viewmodels_in_view` | `*Feature/View/` | **異なる `*ViewModel` 型が2つ以上**現れる |
| **INV-9** | `inv9_usecase_or_repository_in_view` | `*Feature/View/` | `*UseCase` / `*Repository` 型の出現 |
| **INV-10** | `inv10_logic_in_view` | `*Feature/View/` | `.filter(` `.sorted(` `.reduce(` `.compactMap(` `.flatMap(` / `DateFormatter` `NumberFormatter` `RelativeDateTimeFormatter` `Calendar` / `Task {` `await` `try` `catch` |
| **INV-11** | `inv11_other_viewmodel_in_viewmodel` | `*Feature/ViewModel/` | **異なる `*ViewModel` 型が2つ以上**現れる |
| **INV-12** | `inv12_other_usecase_in_usecase` | `Sources/UseCase/` | **異なる `*UseCase` 型が2つ以上**現れる |
| **INV-13** | `inv13_other_repository_in_repository` | `Sources/Repository/` | **異なる `*Repository` 型が2つ以上**現れる |

INV-1（層依存）・INV-2（Feature 同士）・INV-8（Swift 6 モード）は SPM と `Package.swift` が落とすので、
**Lint では見ない**（二重に持つと片方だけ直される）。

`custom_rules` 以外で既定から変えているのは `identifier_name` の下限だけである（2文字を許す）。
DesignSystem のトークンが `AppSpacing.xs` / `AppRadius.md` という名前で、
**2文字で意味が通る側が正しい**ため。

### 9-2. 「異なる型が2つ以上」をどう書くか（INV-9・INV-11〜13 の核）

SwiftLint の `custom_rules` は **ファイル内容の全体**に正規表現をかけられるので、
**後方参照と否定先読み**で「同じ接尾辞を持つ、異なる2つの型名」を表現できる。

```yaml
regex: '(?s)\b([A-Z]\w*ViewModel)\b.*?\b(?!\1\b)([A-Z]\w*ViewModel)\b'
```

- 自分自身の型は**宣言で必ず1回出てくる**ので、「自分以外を参照した」＝「異なる型が2つ以上」になる。
  **ファイル名との突き合わせが要らない**（`custom_rules` はファイル名を条件にできないので、これが効いている）
- `FavoriteRepositoryImpl` は `\b` があるため `FavoriteRepository` として拾われない。
  つまり `RepoRepository` と `RepoRepositoryImpl` が同居しても違反にならない
- 同じ型が何度出ても違反にならない（`(?!\1\b)` が同名を弾き、`.*?` が次を探す）

### 9-3. この Lint の限界（正直に書いておく）

`swift-syntax` ベースの解析ではなく**正規表現**である。次の性質を承知して使う。

- **`match_kinds` を使っていない。** 使うと「マッチ範囲に含まれる全トークンが指定の種類であること」を
  要求するため、**ファイル全体にまたがる 9-2 のルールが常に不発になる**。
  代償として、**コメントや文字列リテラルの中の記述でも発火する**
  （`// Color(...) は禁止` と書くと落ちる）。**ルールを説明する文章は `docs/` に置き、コードに書かない**
- **INV-10 が最も粗い。** `if` / `switch` による表示の出し分けは SwiftUI では避けられないので**見ない**。
  検出するのは「加工・非同期・例外」の痕跡だけで、**View に直接書かれた計算は通る**
  （例: `Text("\(count * 2)")`）。ここは**レビューで見る**と決めている
- **命名規約（§4）が判定の根拠である。** 接尾辞をやめると、Lint は無言で何も見なくなる
- 将来 `swift-syntax` ベースのルールへ移す場合も、**9-1 の判定内容は変えない**（実装だけ差し替える）

### 9-4. ルールそのものの検収（`scripts/test-lint-rules.sh`）

**ルールが空振りしていても CI は緑に見える。** そのため、ルールには自動の検収を付ける。

```bash
./scripts/test-lint-rules.sh   # 13 件（正しいツリー1 + 違反注入12）
```

一時ディレクトリに正しいツリーを作って**違反 0 件**になること、
**不変条件ごとに違反を1つ注入すると、そのルールが発火して落ちる**ことを確かめる。

- **ルールを1つ足したら、ここにも1件足す**（片方だけ足すと、足したルールが効いているか誰も知らない）
- SwiftLint 本体があればそれを使い、無ければ `scripts/swiftlint_sim.py`
  （`custom_rules` の意味論だけを再現した簡易チェッカー）で代替する。
  **代替で緑になっても検収は完了していない** — 正規表現の方言（ICU と Python）が違うため。
  **M1 の完了条件に「本物の SwiftLint で 13 件緑」を入れてある**（[06](06-milestones.md)）
- 実際、この検収は初版の INV-6 が `EdgeInsets(top: 16, …)` を素通ししていたことを拾っている（2026-09-05）

---

## 10. 整形（SwiftFormat）と Lint の住み分け

### 10-1. 役割を分ける

| ツール | 見るもの | 設定の正 | 導入 |
|---|---|---|---|
| **SwiftFormat**（nicklockwood） | **見た目**（改行・字下げ・空白・行の長さ・import の並び・`self` の省略） | `.swiftformat` | `brew install swiftformat` |
| **SwiftLint** | **意味**（アーキテクチャ不変条件・危険な書き方） | `.swiftlint.yml` | `brew install swiftlint` |

**フォーマッタは1つだけ置く。** 2つ入れると互いに整形し合い、
**保存するたびに差分が出続ける**（どちらが最後に走ったかで結果が変わる）。
本PJは **SwiftFormat を唯一のフォーマッタ**とし、Apple の `swift-format` は使わない（[05 D-16](05-decisions.md)）。

**同じことを両方に見せない。** 二重に報告されると、どちらに合わせればよいか決まらなくなる。
`.swiftlint.yml` の `disabled_rules` で、SwiftFormat と重なるルールを**すべて切ってある**
（`line_length` / `trailing_whitespace` / `trailing_newline` / `colon` / `comma` /
`opening_brace` / `closing_brace` / `statement_position` / `vertical_whitespace` /
`control_statement` / `return_arrow_whitespace` / `trailing_comma`）。

> **`trailing_comma` は正面から衝突していた**（2026-09-06・実機で判明）。
> SwiftFormat の `trailingCommas` は複数行リテラルに末尾カンマを**付け**、
> SwiftLint の `trailing_comma` はそれを**外す**。両方を有効にすると、
> 片方を通すたびにもう片方が落ちる。**整形側を正とし、Lint 側を切った。**
逆に `.swiftformat` 側では `todos` を切っている（未決事項の管理は [05](05-decisions.md) の仕事）。

**行の長さは 120。** `.swiftformat` の `--maxwidth` が唯一の置き場である
（`.swiftlint.yml` には書かない）。

### 10-2. コマンドと順序

```bash
swiftformat .            # 整形する
swiftformat --lint .     # 整形されているか確認する（CI。差分があれば exit 1）
swiftlint --strict       # 規約を確認する（CI）
```

**必ず「整形 → Lint」の順**で走らせる。整形で行が動くと、先に出した Lint の行番号がずれるため。

- **CI は整形しない。** 差分があれば落とすだけである
  （CI が勝手に整形して push すると、手元と履歴がずれる）
- **`// swiftformat:disable` と `// swiftlint:disable` は使わない。**
  必要になったのは、設定か設計のどちらかが誤っている合図である
- **`--swiftversion 6.0` を明示している。** 省略すると SwiftFormat が推測し、
  **環境によって整形結果が変わる**（手元と CI で差分が出る形）

### 10-3. コミット前に自動で走らせる

`.githooks/pre-commit` が **staged された `.swift` に対して**「`swiftformat --lint` → `swiftlint`」を行う。

```bash
./scripts/setup.sh    # クローン直後に1回。core.hooksPath を .githooks に向ける
```

> **有効化はブランチではなく「クローンごとの git 設定」である。**
> `.githooks/` がリポジトリに入っているだけでは動かない。
> 参照元PJでは、この事実が把握されておらず「品質ゲートは強制済み」と書かれたまま、
> 実際にはどのクローンでも動いていない状態が続いていた。
> **本PJでは「確実に効くのは CI だけ」と位置づけ、hook は手元での早期発見のためのものとする。**

### 10-4. 実機確認でわかったこと（2026-09-06・SwiftFormat 0.60.0）

`.swiftformat` を初めて実際に走らせた。**綴り違いは無く、設定は全て受理された。**
一方で、**既定値のいくつかが既存のコードを黙って書き換えた**ので、明示して止めてある。
整形を後から入れた以上、**寄せるのは整形側**である。

| 既定値がしたこと | 対処 | 理由 |
|---|---|---|
| `@Suite("UC-001 ViewModel: 検索")` の**表示名を丸ごと削除**した | `--suite-name-format preserve`（`--test-case-name-format` も） | 表示名は TS 番号と [04](04-test-strategy.md) の対応表を運んでいる。関数名から作り直されると対応が切れる |
| `extension` の `public` を宣言から extension 側へ移した | `--extension-acl on-declarations` | 既存コードの書き方 |
| `case .loaded(let rows, _)` を `case let .loaded(rows, _)` にした | `--pattern-let inline` | 同上 |
| `200..<300` を `200 ..< 300` にした | `--ranges no-space` | 同上 |
| `var id: RepoID { summary.id }` を3行に開いた | `--disable wrapPropertyBodies` | 1行で読めるものを開く価値がない |
| 宣言の直前の `//` を `///` に変えた | `--disable docComments` | `//` は「読む人への注意書き」であって API ドキュメントではない |
| `@testable import` の前の空行を消した | `--disable blankLinesBetweenImports` | `--import-grouping testable-bottom` の区切りが消える |

> **`redundantSwiftTestingSuite` は無実だった。** 表示名を消していたのは
> `swiftTestingTestCaseNames` の既定 `standard-identifiers` である。
> **落ちた原因を最初に疑ったルールで決め打ちしないこと** — `--ruleinfo` で1つずつ当たる。

**確かめたこと**（[06](06-milestones.md) M1 の完了条件）:

- `swiftformat --lint .` が緑であり、**整形を崩すと落ちる**（`consecutiveSpaces` 他が発火する）
- `swiftlint --strict` が緑であり、**`./scripts/test-lint-rules.sh` が SwiftLint 本体で 13 件緑**
- `Domain` から `import Repository` を書くと、**`circular dependency between modules` でビルドが落ちる**
