# 00 プロジェクト概要 — GitHubSample（Swift / SwiftUI サンプル）

> **位置づけ**: `isamiodagiri/ChildAsset`（こども資産台帳）と `akiponpon/kotoba-album`（コトバのアルバム）の
> 2つの Flutter プロジェクトで実践されている **AI駆動開発の運用（層をツールで機械的に強制する・
> 1UC=1PRD・AC/TS の採番と突き合わせ・裁定を文書に残す）を、Swift / SwiftUI へ翻訳した参照実装**である。
> プロダクトとしての価値ではなく、**構造と規律を示すこと**が目的。

**作成日**: 2026-09-05 ／ **版**: 第1版（設計書のみ。実装は未着手）

---

## 1. 何を作るか

**GitHub の公開情報（Public API）だけを使うリポジトリ検索アプリ**。認証なしで動き、
サインインもユーザー個人データの送信も無い。

| 画面 | 内容 |
|---|---|
| **A. 検索** | キーワードでリポジトリを検索し、一覧で見る（インクリメンタル検索・追加読み込み） |
| **B. 詳細** | 選んだリポジトリのスター数・フォーク数・言語・ライセンス・トピック等を見る |
| **C. お気に入り** | 気になったリポジトリを端末内に保存し、一覧で見る（唯一の書き込み。端末内のみ） |

### 1-1. このサンプルが示すこと（＝評価軸）

1. **View / ViewModel / UseCase / Repository の4層**が、**SPM のターゲット分割によって
   コンパイラに強制されている**こと（規約ではなくビルドが落ちる）
2. **境界は `async/await`・出力は Combine** という分担が、**全レイヤで一貫している**こと（§3・[01-architecture.md](01-architecture.md) §5）
3. **Swift 6 の strict concurrency（完全チェック）で `@unchecked Sendable` が1つも無い**こと
4. **キャンセル**が正しく効くこと（打鍵のたびに前の検索が捨てられ、**古い応答が新しい結果を上書きしない**）
5. 上の4つが**テストで観測されている**こと（[04-test-strategy.md](04-test-strategy.md)）

### 1-2. スコープ外（作らない・提案もしない）

- サインイン / OAuth / 個人のプライベートリポジトリ（**公開情報のみ**という前提を崩さない）
- 書き込み系 GitHub API（star / fork / issue 作成）
- サーバー同期・課金・プッシュ通知・Android
- オフラインキャッシュの永続化（**お気に入りのIDのみ**端末に保存する。本文はキャッシュしない）

---

## 2. 参照した2プロジェクトから何を持ち込み、何を持ち込まなかったか

| 持ち込んだもの | 出どころ | 本PJでの形 |
|---|---|---|
| 層依存を**機械的に**強制する | ChildAsset `tools/architecture_lints/`（カスタムLint） | **SPM のターゲット依存**（+ 補助の grep スクリプト。[01](01-architecture.md) §3） |
| 1UC = 1PRD、AC を採番して TS と突き合わせる | 両PJ（`docs/prd/` `docs/ts/`） | [docs/prd/](prd/)・[04-test-strategy.md](04-test-strategy.md) |
| 裁定（決めたこと）と未決事項を1箇所に集める | kotoba-album `docs/prd/m*-decisions-draft.md` | [05-decisions.md](05-decisions.md) |
| UI の実色・実数値は View に書かず DesignSystem に置く | 両PJ（`prefer_design_tokens`） | `DesignSystem` ターゲット + 検査スクリプト |
| Feature 同士を参照させない / 遷移は上位が結線する | kotoba-album `code/CLAUDE.md` | Feature を**画面ごとに別ターゲット**へ分割（[01](01-architecture.md) §3-2） |
| 真実源マップ（どの問いにどの文書が答えるか） | 両PJ | 本ファイル §4 |
| **持ち込まなかったもの** | | |
| Firebase / Firestore / Cloud Functions | 両PJ | サーバーを持たない。データ源は GitHub API のみ |
| 課金・家族共有・機微データ保護の不変条件 | 両PJ | 該当なし。代わりに**「公開情報しか扱わない」**を不変条件にした（§3） |
| freezed / Riverpod 相当のコード生成 | 両PJ | **コード生成なし**。Swift の言語機能（`struct` + `Sendable`）で足りる |

---

## 3. 不変条件（フェーズによらず常に守る）

**破ったらビルドかCIが落ちる**ように作る。落とせないものは「人が守る」と明記する。

| # | 不変条件 | 強制手段 |
|---|---|---|
| INV-1 | 層依存は `Feature → UseCase → Repository → Domain → Core` の一方向。逆流・飛び越し禁止 | **SPM ターゲット依存**（ビルドが落ちる） |
| INV-2 | Feature 同士は参照しない | **SPM ターゲット依存**（ビルドが落ちる） |
| INV-3 | `URLSession` を触れるのは `Core/HTTP/` だけ、`UserDefaults` を触れるのは Repository 層だけ | **SwiftLint**（`custom_rules`） |
| INV-4 | `@unchecked Sendable` と `nonisolated(unsafe)` を書かない | **SwiftLint**（`custom_rules`） |
| INV-5 | View と State は Domain の Entity を参照しない（変換は ViewModel の仕事） | **SwiftLint**（`custom_rules`） |
| INV-6 | View に色・フォント・角丸・余白の**数値**を直書きしない（DesignSystem のトークンを使う） | **SwiftLint**（`custom_rules`） |
| INV-7 | **公開情報しか扱わない**。個人を特定するデータを端末外へ送らない。アクセストークンをリポジトリにコミットしない | 人が守る（+ `.gitignore` と CI の秘密情報スキャン） |
| INV-8 | Swift 6 language mode / strict concurrency = complete を無効化しない | `Package.swift`（ビルドが落ちる） |
| **INV-9** | **View が参照してよい ViewModel は1つだけ**。View は UseCase / Repository を参照しない | **SwiftLint**（`custom_rules`） |
| **INV-10** | **View はロジックを持たない**（整形・並べ替え・非同期・例外処理は ViewModel の仕事） | **SwiftLint**（**静的な近似**。限界は [01 §9-3](01-architecture.md)） |
| **INV-11** | **ViewModel は他の ViewModel を参照しない** | **SwiftLint**（`custom_rules`） |
| **INV-12** | **UseCase は他の UseCase を参照しない** | **SwiftLint**（`custom_rules`） |
| **INV-13** | **Repository は他の Repository を参照しない** | **SwiftLint**（`custom_rules`） |

> **INV-9〜INV-13 の位置づけ**: 層の**縦**の依存（INV-1・INV-2）は SPM が落とすが、
> **同じ層のもの同士の横の参照**（ViewModel → ViewModel、UseCase → UseCase、Repository → Repository）は
> 同一ターゲット内なのでコンパイラには見えない。**ここが崩れると、層があっても責務が溶ける**
> （UseCase が UseCase を呼び始めた瞬間に、手順の起点がどこか分からなくなる）。
> 検出の実体は **`.swiftlint.yml` の `custom_rules`**、その検収は `scripts/test-lint-rules.sh`。

> **INV-7 の位置づけ**: 参照元2PJの最重要不変条件は「子どもの音声・写真・誕生日を承認済み保存先以外へ送らない」だった。
> 本PJに機微データは無いが、**「送信先を増やす変更は設計判断である」という規律だけは残す**。
> 分析SDK・クラッシュレポートの追加も、この不変条件の対象である。

---

## 4. 真実源マップ（食い違ったら「正」に当たる）

| 知りたいこと | 正 |
|---|---|
| 何を作るか・スコープ外・不変条件 | **本ファイル** |
| モジュール構成・層依存・Concurrency と Combine の分担・命名規約・DI | [01-architecture.md](01-architecture.md) |
| 使う GitHub API・レート制限・HTTPステータスとエラーの写像 | [02-github-api.md](02-github-api.md) |
| 画面の構成・状態・文言 | [03-screens.md](03-screens.md) |
| 各ユースケースの受け入れ条件（AC） | [docs/prd/](prd/) の各 UC |
| テストの分担・TS 一覧・テストダブル方針 | [04-test-strategy.md](04-test-strategy.md) |
| 設計上の裁定（なぜそう決めたか）・未決事項 | [05-decisions.md](05-decisions.md) |
| 実装の順序・マイルストーン | [06-milestones.md](06-milestones.md) |
| **実装の事実**（何がどこまで出来ているか） | **コードとテスト**（文書に列挙しない。すぐ腐るため） |
| 整形と Lint の住み分け・設定 | [01-architecture.md](01-architecture.md) §9・§10（実体は `.swiftformat` と `.swiftlint.yml`） |
| 開発コマンド・ディレクトリ規約 | リポジトリルート `AGENTS.md` |

- 文書どうしが食い違ったら、**上の表で「正」とされた側が勝ち、負けた側を直す**（放置しない）
- **同じ事実を2箇所に書かない**。片方だけ更新されるサイレント故障になるため、参照でつなぐ

---

## 5. 想定する開発の進め方（AI駆動）

参照元2PJの運用をそのまま踏襲する。

1. **設計書**（本ドキュメント群）を先に確定する
2. UC ごとに **PRD（AC 採番）** を書く → 独立レビュー（別モデル / 別セッション）にかける
3. **TS（テストシナリオ）** を書き、AC と機械的に突き合わせる（対応漏れ 0 を確認する）
4. **テストコードと実装を並列で作る**（口の形＝プロトコルだけ先に確定させ、中身は互いに見ない）
5. 実装が緑になったら **最終レビュー**（アーキテクチャ / 責務分離 / 並行性 / パフォーマンスの4観点）
6. **最初から緑だったテストは、実装を壊して赤になることを確かめる**（変異検証）
   — 「緑であること」は「そのテストが落ちうること」を意味しないため

> 4・6 は kotoba-album で実測された失敗（テストが空振りしていた事故）への対策であり、
> 本PJでも同じ順序で運用する。詳細は [04-test-strategy.md](04-test-strategy.md) §6。
