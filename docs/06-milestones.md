# 06 実装の順序（マイルストーン）

> **正**: 何をどの順で作るか、各マイルストーンの完了条件。
> **進捗の正はコードと git log**であり、本ファイルには「済/未」を書かない
> （書くと必ず実態とずれ、他の規則まで古いものとして扱われるため）。

---

## M1. 基盤（Core / Domain / DesignSystem / CI）

**作るもの**: `Package.swift`（全ターゲット・Swift 6 モード）、`Core`（`HTTPClient` と URLSession 実装）、
`Domain`（Entity・値オブジェクト・`GitHubError`）、`DesignSystem`（トークンと共通部品）、
`.swiftlint.yml`、`.swiftformat`、`.githooks/pre-commit`、`.github/workflows/ci.yml`、
`App/project.yml`（XcodeGen・裁定 D-24）。

**完了条件**:
- `swift build` / `swift test` が通る
- **`./scripts/test-lint-rules.sh` が、SwiftLint 本体で 13 件緑**（INV-3〜INV-13 について、
  違反を注入すると落ちることを自動で確かめる。1つでも空振りしていると以後ずっと素通しになる）
  — **簡易チェッカーでの緑は検収として数えない**（[01 §9-4](01-architecture.md)）
- **層をまたぐ import（`Domain` から `Repository`）を書くとビルドが落ちる**ことを確認した
- **`swiftformat --lint .` が緑**で、崩した状態にすると落ちることを確認した
  — オプション名と既定値の実機確認をここで行う。
  **既定値が既存コードを黙って書き換える箇所は、明示して止める**（[01 §10-4](01-architecture.md)）

## M2. 検索（UC-001）

**作るもの**: `Repository`（検索・DTO・エラー写像）、`UseCase`（Search / LoadMore）、
`SearchFeature`（View / ViewModel / State）、`TestSupport`（StubHTTPClient・Fixtures）、App の結線。

**完了条件**: UC-001 の AC 35 件に対応する TS-1〜TS-47（**View 層の TS-48〜53 を除く**。理由は [04 §3-1](04-test-strategy.md)）が緑。`swiftlint --strict` 緑。**最初から緑だったテストの変異検証を実施した**（[04 §6](04-test-strategy.md)）。

> **M2 が本サンプルの山**である。debounce・キャンセル・世代管理・ページングが全部ここに入る。
> M2 が終われば、残りは同じ型の反復になる。

## M3. 詳細（UC-002）

**作るもの**: `RepoDetailFeature`、詳細取得の Repository / UseCase、遷移の結線（App）。

**完了条件**: TS-54〜TS-71（**View 層の TS-72〜76 を除く**）が緑。**部分失敗（AC-9）が実際に観測できている**こと。

## M4. お気に入り（UC-003）

**作るもの**: `FavoriteRepository`（actor ＋ `AsyncStream`）、3つの UseCase、`FavoriteFeature`、タブの結線。

**完了条件**: TS-77〜TS-93・TS-98・TS-99（**View 層の TS-94〜97・TS-100 を除く**）が緑。**購読の解除（TS-85）と、3画面同時反映（TS-98・TS-99）を観測**している。

## M5. 仕上げ

- README（アーキテクチャ図・起動方法・**このサンプルが示していること**・トークンの扱いの注意）
- アクセシビリティ（Dynamic Type・VoiceOver ラベル）※ [D-19](05-decisions.md) の裁定に従う
- **Q-1（View の検証をどう入れるか）を判断する。** 未実装の TS 16 件はここで埋めるか、
  埋めないと決めて理由を残す（[04 §3-1](04-test-strategy.md)）
- **設計書とコードの突き合わせ**: AC / TS の件数を数え直し、[04 §8](04-test-strategy.md) の検算表を更新する

**完了条件**:
- `swift build` / `swift test` / `swiftlint --strict` / `swiftformat --lint .` /
  `./scripts/test-lint-rules.sh` が**すべて緑**
- **未実装の TS が残るなら、残る理由が [04 §3-1](04-test-strategy.md) に書いてある**
  （「書いていない」のか「観測できない」のかを、読む側が区別できること）
- 検算表の3つの数（AC・TS 定義・TS 実装）を、**それぞれ実体から数え直した**

---

## 各マイルストーン共通の進め方

1. UC の PRD（AC）を確定 → **独立レビュー**（別セッション / 別モデル）
2. TS を書き、AC との対応漏れが 0 であることを**機械的に**確認
3. **プロトコル（口の形）だけ先に確定**させ、テストと実装を並列で作る
   - 実装側が `Sources/`、テスト側が `Tests/` を持つ。互いのファイルを編集しない
   - 実装側は最初に「口＋`fatalError("unimplemented")`」だけを置いて報告する
   - **実装の中身の話（「この関数は nil を返すだけ」等）をテスト側に渡さない**
     — テストが「AC から導いた観測点」ではなく「実装の形に当たる観測点」になるため
4. 緑になったら最終レビュー（アーキテクチャ / 責務分離 / 並行性 / パフォーマンス）
5. **変異検証**（[04 §6](04-test-strategy.md)）。死ななかった変異を記録する
