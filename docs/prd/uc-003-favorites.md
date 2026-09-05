# UC-003 お気に入りを付ける・見る・外す

| | |
|---|---|
| **画面** | C. お気に入り（`FavoriteScreen` / `FavoriteViewModel`）＋ A・B の ☆ ボタン |
| **層** | 各Feature → UseCase(`ToggleFavoriteUseCase`, `ObserveFavoriteIDsUseCase`, `ListFavoriteReposUseCase`) → Repository(`FavoriteRepository`) |
| **依存する設計** | [01 §5-3 Sendable](../01-architecture.md)・[03 C お気に入り画面](../03-screens.md) |
| **AC** | 22 件 ／ **BR** 4 件 ／ **未解決 Q** 0 件 |

---

## 1. 目的

**唯一の書き込み操作**を通して、次の2つを示す:

1. **`actor` が持つ可変状態を、`AsyncStream` で複数の画面へ安全に配る**形
2. **状態の真実源が1つであること**（画面ごとにフラグを持たないと、必ずずれる）

## 2. スコープ / 非スコープ

**スコープ**: 追加・削除・一覧・全画面への即時反映・アプリ再起動後の復元。

**非スコープ**: 端末間の同期、並び替え、フォルダ分け、件数の上限、お気に入りの検索。

---

## 3. Business Rule

| ID | 規則 | 根拠 |
|---|---|---|
| **BR-010** | お気に入りの真実源は `FavoriteRepository`（actor）**1つだけ**。画面は自前のフラグを持たない | 03 §C-2 |
| **BR-011** | 保存するのは ID ではなく **`RepoSummary` 全体**（表示に必要な情報ごと） | 裁定 D-5（ID だけだと一覧表示のたびに API を叩き、60/時を使い切る） |
| **BR-012** | 保存の失敗は**画面の状態を巻き戻す**（成功したふりをしない） | 「押したのに消えている」を作らない |
| **BR-013** | 並び順は `addedAt` の降順（追加した新しい順）で、**保存側が持つ** | 画面ごとに並べ替えるとタブ間でずれる |

---

## 4. 受け入れ条件（AC）

### 4-1. 追加・削除

- **AC-1**: 検索一覧の ☆ を押すと ★ になり、お気に入りに追加される
- **AC-2**: ★ を押すと ☆ に戻り、お気に入りから外れる
- **AC-3**: 詳細画面の ☆ / ★ でも同じ操作ができる
- **AC-4**: お気に入り画面で行をスワイプすると削除できる
- **AC-5**: お気に入り画面の ★ を押しても削除できる
- **AC-6**: 削除に確認ダイアログは出さない（すぐ付け直せるため）
- **AC-7**: 保存に失敗したとき、**表示は元に戻り**、一時的な通知が出る（BR-012）

### 4-2. 全画面への反映（BR-010）

- **AC-8**: 検索一覧で追加すると、**お気に入りタブを開いたときではなく、その時点で**
  お気に入りの一覧に現れている
- **AC-9**: お気に入り画面で削除すると、**開いている検索一覧の同じ行の ★ が ☆ に戻る**
- **AC-10**: 詳細画面で追加すると、**その裏にある検索一覧の行も ★ になる**
- **AC-11**: 同じリポジトリが検索一覧に複数回現れることはないが、
  **検索タブと お気に入りタブの両方に同じ行が見えている場合、両方が同時に変わる**
- **AC-12**: 購読は画面が閉じられた時点で解除される（`AsyncStream` の `for await` を持つ Task が終わる）

### 4-3. 永続化

- **AC-13**: アプリを再起動しても、お気に入りは残っている
- **AC-14**: 保存先は端末内（`UserDefaults`）のみで、**ネットワークへは一切送らない**（INV-7）
- **AC-15**: 保存されたデータが壊れている / 形式が古いとき、**アプリは落ちず、空として扱う**
- **AC-16**: 同じリポジトリを二重に追加しても、一覧には1件しか出ない（`id` で一意）

### 4-4. 一覧表示

- **AC-17**: 一覧は追加した新しい順に並ぶ（BR-013）
- **AC-18**: 0件のとき、「お気に入りはまだありません」の案内が出る
- **AC-19**: 行の見た目は検索一覧の行と同じである（同じ `DesignSystem` の部品を使う）
- **AC-20**: 行をタップすると詳細画面へ遷移する（summary を持たない入口 ＝ UC-002 AC-10）
- **AC-21**: 一覧は API を1回も呼ばない（BR-011）
- **AC-22**: 追加・削除の直後、一覧はスクロール位置を保ったまま更新される（全体の作り直しをしない）

---

## 5. 実装の形（このUCが示したいもの）

```swift
// Repository 層
public protocol FavoriteRepository: Sendable {
    func favorites() async -> [FavoriteRepo]              // 現在の値
    func stream() -> AsyncStream<[FavoriteRepo]>          // 変化の通知（複数の購読者）
    func add(_ repo: RepoSummary) async throws
    func remove(id: RepoID) async throws
}

public actor FavoriteRepositoryImpl: FavoriteRepository {
    private var items: [FavoriteRepo]                     // ← actor が守る唯一の可変状態
    private var continuations: [UUID: AsyncStream<[FavoriteRepo]>.Continuation] = [:]

    public func stream() -> AsyncStream<[FavoriteRepo]> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.yield(items)                     // 購読した瞬間に現在値を流す
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }   // ← AC-12 の実体
            }
        }
    }
}
```

- **複数購読**（検索・詳細・お気に入りの3画面）が同時に成立することが AC-8〜AC-11 の前提
- **`onTermination` で continuation を捨てる**のを忘れると、画面を開くたびに購読が増え続ける
  （画面は消えているのに通知だけが積み上がる。**テストで観測する** ＝ TS-59）
- `@unchecked Sendable` は使わない。**可変状態があるから actor にする**（INV-4）

---

## 6. 未解決事項

なし。

## 7. 決定の記録

- **なぜ `UserDefaults` か**: 件数が少なく、構造が単純で、端末内に閉じる。
  SwiftData / CoreData は本サンプルの評価軸（層と並行性）に何も足さず、
  **モデルの寿命管理という別の難しさを持ち込む**ため採らない
- **なぜ ID ではなく summary ごと保存するか**: BR-011 の根拠のとおり、
  お気に入りを開くたびに N 件の詳細 API を叩くと、未認証の 60 req/時を1画面で使い切る。
  **保存したものが古くなる**という欠点は受け入れる（詳細を開けば最新が取れる）
