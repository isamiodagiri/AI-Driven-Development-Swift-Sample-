# GitHubSample

GitHub の**公開情報**を検索・閲覧する SwiftUI サンプルアプリ。
**View / ViewModel / UseCase / Repository の4層**を SwiftPM のターゲット分割で強制し、
**境界は `async/await`・出力は Combine**、**Swift 6 の strict concurrency で `@unchecked Sendable` ゼロ**
という方針で組んでいる。

> **現在の状態**: M1〜M5 まで実装済み。
> Swift 6.2.1 / SwiftLint 0.63.2 / SwiftFormat 0.60.0 で、
> **`swift build`・`swift test`（132 件）・`swiftlint --strict`・`swiftformat --lint .`・
> `./scripts/test-lint-rules.sh`（13 件）がすべて緑**である（2026-09-06 に実機で確認）。
>
> **TS は 107 件のうち 106 件が実装済み**で、残る1件（TS-94・スワイプ削除）は
> **`ViewInspector` が `.swipeActions` に届かないため観測できない**
> — 書き忘れではないことを [04 §3-1](docs/04-test-strategy.md) に理由ごと残してある。
> **`App/` の Xcode プロジェクトは XcodeGen で生成する**（[App/README.md](App/README.md)・裁定 D-7・D-24）。
> iOS 26.0 シミュレータで **検索 → 詳細 → お気に入り** まで実際に操作して確認してある。
> **その最初の起動で、テストが全件緑のまま見落としていた表示崩れが1件見つかった**
> （[04 §3-1](docs/04-test-strategy.md)）。
>
> 設計書は [docs/](docs/)。読む順序は
> [00 概要](docs/00-overview.md) → [01 アーキテクチャ](docs/01-architecture.md) →
> [03 画面](docs/03-screens.md) → [各UCのPRD](docs/prd/)。

## 何のサンプルか

`isamiodagiri/ChildAsset` と `akiponpon/kotoba-album` の2つの Flutter プロジェクトで実践されている
**AI 駆動開発の規律**（層をツールで機械的に強制する・1UC=1PRD・AC と TS を採番して突き合わせる・
裁定を文書に残す）を、**Swift / SwiftUI へ翻訳した参照実装**である。

## 画面

| | |
|---|---|
| **検索** | キーワードでリポジトリを検索（300ms debounce・追加読み込み・レート制限の表示） |
| **詳細** | スター / フォーク / ウォッチャー / ライセンス / トピック |
| **お気に入り** | 端末内に保存し、3画面へ即座に反映（`actor` ＋ `AsyncStream`） |

## モジュール構成

```
Feature（View / ViewModel / State）
   └→ UseCase
        └→ Repository   ← URLSession / UserDefaults を触るのはここだけ
             └→ Domain
                  └→ Core
DesignSystem ← Feature からのみ参照
```

依存の向きは `Package.swift` のターゲット依存が強制する（**逆流するとビルドが落ちる**
— `Domain` から `import Repository` すると `circular dependency between modules` になる）。
落とせない規約は **SwiftLint の `custom_rules`**（`.swiftlint.yml`）が検査する
（View から Entity を見ない・色や数値の直書き禁止・**View が参照する ViewModel は1つだけ**・
**View はロジックを持たない**・**ViewModel / UseCase / Repository は同種のものを参照しない**）。
ルール自体が空振りしていないことは `scripts/test-lint-rules.sh` が違反注入で確かめる。

**テストが空振りしていないこと**は `scripts/mutation-test.sh` が確かめる。
AC ごとに書いた変異（39 件）を実装へ当て、**狙った TS が本当に赤になるか**を見る
（[04 §6](docs/04-test-strategy.md)）。緑であることと、落ちうることは別である。
対象は **ViewModel / UseCase / Repository / Feature の View / DesignSystem** で、
`Core` の整形や `Presentation` の写像は**まだ当てていない**（[04 §6-6](docs/04-test-strategy.md)）。

## 動かす

```bash
./scripts/setup.sh                                     # 1回だけ（pre-commit hook を有効化）
swift build && swift test
swiftformat --lint .                                   # 整形（.swiftformat が正）
swiftlint --strict                                     # 層と責務の検査（INV-3〜INV-13）
./scripts/test-lint-rules.sh                           # Lint ルールそのものの検収
./scripts/mutation-test.sh                             # 変異検証（15 分ほど。毎回は回さない）
```

アプリとして起動するときだけ **XcodeGen** が要る（[App/README.md](App/README.md)）。

```bash
brew install xcodegen
cd App && xcodegen generate && open GitHubSampleApp.xcodeproj
```

整形は **SwiftFormat 0.60.0**、規約は **SwiftLint 0.63.2**（どちらも `brew install`）。
**版は CI で固定してある**（`.github/workflows/ci.yml`）。
道具の版が動くと整形結果も動くので、**手元と CI で同じ版を使う**
（[01 §10-5](docs/01-architecture.md)）。
**フォーマッタは1つだけ置き、同じことを両方には見せない**（重なるルールは片方を切ってある）。
上の5つは `.github/workflows/ci.yml` が CI でも同じ順で回す。
`.githooks/pre-commit` は手元で同じことを staged なファイルにだけ行う
（**確実に効くのは CI だけ**である。hook は早期発見のためのもの）。

**外部依存はテスト専用の `ViewInspector` が1つだけ**である（裁定 D-18）。
3つの Feature のテストターゲットにだけ書いてあり、`Sources/` からは見えない。

アクセシビリティは **Dynamic Type を `.accessibility3` まで**（そこでは横並びを縦に積む）、
**VoiceOver はアイコンだけのボタンと数値バッジにラベルを打つ**ところまで（裁定 D-19）。
文言は**日本語固定**である（裁定 D-20）。

未認証でも動作する。開発中にレート制限（未認証は検索 10 req/分・その他 60 req/時）に
当たる場合のみ、`App/Config.xcconfig` に `GITHUB_TOKEN` を置ける。

> **注意**: アプリのバンドルに埋めたトークンは取り出せる。**この方式はサンプル専用**であり、
> 配布するアプリで採ってはならない。

## 開発の規約

[AGENTS.md](AGENTS.md) を参照。
