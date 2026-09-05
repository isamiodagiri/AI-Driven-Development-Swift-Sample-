# AGENTS.md

AI コーディングエージェント（Claude Code / Codex 等）と人間が、このリポジトリで作業するときの規約。
**プロダクトの内容ではなく「ここで作業するときに必要な事実」だけ**を持つ。

## このリポジトリは何か

**GitHub の公開情報を使う SwiftUI サンプル**。実在の2つの Flutter プロジェクト
（`isamiodagiri/ChildAsset` / `akiponpon/kotoba-album`）で運用されている AI 駆動開発の規律を
Swift へ翻訳した参照実装である。詳細は [docs/00-overview.md](docs/00-overview.md)。

## 情報の正（食い違ったらこちらに当たる）

| 知りたいこと | 正 |
|---|---|
| 何を作るか・不変条件・スコープ外 | [docs/00-overview.md](docs/00-overview.md) |
| 層依存・並行性と Combine の分担・命名・DI | [docs/01-architecture.md](docs/01-architecture.md) |
| GitHub API・エラー写像・レート制限 | [docs/02-github-api.md](docs/02-github-api.md) |
| 画面の仕様・文言 | [docs/03-screens.md](docs/03-screens.md) |
| 受け入れ条件（AC） | [docs/prd/](docs/prd/) |
| テストの分担・TS 一覧 | [docs/04-test-strategy.md](docs/04-test-strategy.md) |
| なぜそう決めたか・未解決事項 | [docs/05-decisions.md](docs/05-decisions.md) |
| 実装順序 | [docs/06-milestones.md](docs/06-milestones.md) |
| **何がどこまで実装済みか** | **コードとテスト**（文書に列挙しない） |

## コマンド

```bash
./scripts/setup.sh                    # クローン直後に1回（pre-commit hook を有効化する）

swift build                           # 全ターゲット
swift test                            # 単体テスト（macOS 上で完結する）
swift test --filter SearchFeatureTests

swiftformat .                         # 整形する（要 brew install swiftformat）
swiftformat --lint .                  # 整形されているか（CI と同じ判定）
swiftlint --strict                    # 不変条件 INV-3〜INV-13（要 brew install swiftlint）
./scripts/test-lint-rules.sh          # Lint ルールそのものの検収（違反注入）
```

**必ず「整形 → Lint」の順**で走らせる（整形で行が動くと Lint の行番号がずれる）。
設定の正は `.swiftformat`（見た目）と `.swiftlint.yml`（意味）で、
**同じことを両方に書かない**（住み分けは [docs/01-architecture.md](docs/01-architecture.md) §10）。

CI（`.github/workflows/ci.yml`）は **build → test → swiftformat --lint → swiftlint --strict → ルールの検収** を全部回す。
**CI は整形しない**（差分があれば落とすだけ。CI が push すると手元と履歴がずれる）。
**`swiftlint --strict` を CI から外さない**（外すと INV-3〜INV-13 が誰にも守られなくなる）。

## 変更するときの規約

- **層をまたぐ import を足す前に、[docs/01-architecture.md](docs/01-architecture.md) §3 を読む。**
  ビルドが落ちたときの正しい直し方は「依存を足す」ではなく「置き場所を直す」であることが多い
- **`@unchecked Sendable` / `nonisolated(unsafe)` を書かない。** 書きたくなったら型の設計が誤っている
- **同じ層のもの同士を参照しない**（View→1つの ViewModel だけ・ViewModel↛ViewModel・UseCase↛UseCase・
  Repository↛Repository）。画面をまたいで状態を共有したくなったら、
  **Repository を真実源にして両方が購読する**（[docs/01-architecture.md](docs/01-architecture.md) §3-5）
- **View にロジックを書かない。** 整形・並べ替え・非同期・例外処理は ViewModel の仕事
- **View に色・数値を直書きしない。** 足りない部品・トークンは `DesignSystem` に足してから使う
- **新しいターゲットを足したら `Package.swift` の依存と `.swiftlint.yml` の対象パスを両方更新する**
- **ルールを1つ足したら `scripts/test-lint-rules.sh` にも1件足す**（空振りするルールは CI では緑に見える）
- **`// swiftlint:disable` / `// swiftformat:disable` で規約を回避しない。** 必要になったのは設定か設計が誤っている合図である
- **行の長さは 120。** 置き場は `.swiftformat` の `--maxwidth` だけ（`.swiftlint.yml` には書かない）
- **仕様を変えたら、コードより先に docs を直す。** 設計書とコードが食い違った状態でコミットしない
- **AC / TS の件数を書き換えるときは、実体（表）を数え直す。** 引き算で更新しない

## テストの規約

- 実装が先にできた（＝最初から緑の）テストは、**実装を1箇所壊して赤になることを確認**してから完了とする
- 未決事項をコードに残すときは、**必ず落ちるテストとセット**にする
  （無効化したテストは緑の中に埋もれ、誰にも数えられない）
- スタブを実物より寛容にしない。詳細は [docs/04-test-strategy.md](docs/04-test-strategy.md) §4

## やってはいけないこと

- アクセストークンをコミットする（`.xcconfig` は `.gitignore` 済み）
- 書き込み系の GitHub API を叩く／分析 SDK・クラッシュレポートを足す（[docs/00-overview.md](docs/00-overview.md) INV-7）
- `docs/` の裁定を、理由を残さずに書き換える（変えるなら [docs/05-decisions.md](docs/05-decisions.md) に経緯を残す）
