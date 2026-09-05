# 02 GitHub API 設計（使う範囲・レート制限・エラー写像）

> **正**: 叩くエンドポイント、リクエストの形、レスポンスのどのフィールドを使うか、
> HTTP ステータス → `GitHubError` の写像。**写像を実装するのは Repository 層だけ**である。

---

## 1. 前提

| 項目 | 決定 |
|---|---|
| ベースURL | `https://api.github.com` |
| 認証 | **なし（未認証）で動くことを既定とする**。トークンは任意（§5） |
| API バージョン | `X-GitHub-Api-Version: 2022-11-28` を常に送る |
| `Accept` | `application/vnd.github+json` |
| `User-Agent` | 必須。`GitHubSample/1.0 (+https://github.com/…)` を送る（**無いと 403 になる**） |
| 扱う範囲 | **公開情報の GET のみ**。書き込み系は叩かない（INV-7） |

---

## 2. 使うエンドポイント

### 2-1. リポジトリ検索 — `GET /search/repositories`

| クエリ | 値 | 備考 |
|---|---|---|
| `q` | ユーザーの入力語（空文字は**呼ばない**） | 必須。空だと 422 |
| `sort` | 既定は**省略**（＝ best match） | `stars` / `forks` / `updated` を UI から選ばせるのは非スコープ |
| `order` | 省略 | 同上 |
| `per_page` | `30` | 上限 100。30 は1画面あたりの妥当量 |
| `page` | `1` から | **`page * per_page > 1000` は要求しない**（§3-2） |

応答（使うフィールドのみ）:

```jsonc
{
  "total_count": 12345,
  "incomplete_results": false,   // 検索がタイムアウトして部分結果である印
  "items": [
    {
      "id": 123, "full_name": "apple/swift", "name": "swift",
      "owner": { "login": "apple", "avatar_url": "https://…" },
      "description": "…", "html_url": "https://github.com/apple/swift",
      "stargazers_count": 67000, "forks_count": 10000,
      "language": "C++", "updated_at": "2026-09-01T12:00:00Z"
    }
  ]
}
```

### 2-2. リポジトリ詳細 — `GET /repos/{owner}/{repo}`

一覧に無い情報（ライセンス・トピック・ウォッチャー実数・オープンIssue数・アーカイブ状態）を取る。

使うフィールド: `id` / `full_name` / `owner.login` / `owner.avatar_url` / `description` /
`html_url` / `homepage` / `stargazers_count` / `forks_count` / **`subscribers_count`** /
`open_issues_count` / `language` / `license.name` / `license.spdx_id` / `topics` /
`updated_at` / `pushed_at` / `archived` / `fork` / `default_branch`

> **注意（実装が間違えやすい）**: 検索結果の `watchers_count` は **`stargazers_count` と同じ値**が入る
> （GitHub の歴史的経緯）。実際のウォッチャー数は**詳細エンドポイントの `subscribers_count`** である。
> 一覧では「ウォッチャー数」を出さない。詳細でのみ `subscribers_count` を「Watching」として出す。

### 2-3. 叩かないもの

`/users/{user}`、`/repos/{o}/{r}/contributors`、`/readme` は**本PJでは使わない**
（レート制限を1画面で3本使い切るのを避ける。将来足す場合は本ファイルを先に更新する）。

---

## 3. レート制限とページング

### 3-1. レート制限（未認証）

| 対象 | 上限 |
|---|---|
| **Search API**（`/search/*`） | **10 リクエスト / 分**（IP単位） |
| その他の REST（`/repos/…` 等） | **60 リクエスト / 時**（IP単位） |
| 認証あり（PAT） | Search 30/分、その他 5,000/時 |

**未認証の 60/時は簡単に使い切る**。設計上の対策:

1. **検索は 300ms の debounce を必ず通す**（打鍵ごとに投げない ＝ UC-001 AC-3）
2. **同一クエリ・同一ページの再要求をしない**（`removeDuplicates` と、ViewModel の世代管理）
3. **詳細は一覧の情報で描き始め**、詳細取得はその上に重ねる（失敗しても一覧由来の情報は残る ＝ UC-002 AC-9）
4. **429 / 403（残0）を受けたら、`x-ratelimit-reset` までは自動再試行しない**（画面に残り時間を出す）

応答ヘッダから常に読む値:

| ヘッダ | 使い道 |
|---|---|
| `x-ratelimit-remaining` | `0` かつ 403/429 なら `rateLimited` と判定する（403 の他の理由と区別する唯一の手掛かり） |
| `x-ratelimit-reset` | UNIX 秒。`Date(timeIntervalSince1970:)` にして画面に「あと N 分」を出す |
| `retry-after` | 二次レート制限のときに来る。秒数。あれば `reset` より優先する |

### 3-2. ページング

- **Search API は最大 1,000 件しか返さない**。`page * per_page > 1000` を要求すると 422 になる。
  よって `hasMore` の判定は
  **`items.count == per_page` かつ `取得済み件数 < min(total_count, 1000)`** とする
- `Link` ヘッダは**解釈しない**（`page` の加算で足りる。Link の解析は失敗経路を1つ増やす）
- 追加読み込み中に検索語が変わったら、**進行中のページ取得は破棄する**（世代番号で判定）

---

## 4. HTTP → `GitHubError` の写像（**この表が正**）

| 条件 | `GitHubError` | 画面の扱い |
|---|---|---|
| `URLError.notConnectedToInternet` / `.networkConnectionLost` | `.offline` | 専用文言＋再試行 |
| `URLError.timedOut` | `.timeout` | 再試行 |
| `URLError.cancelled` / `CancellationError` | **写像しない（そのまま投げる）** | ViewModel が握りつぶす（状態を変えない） |
| 200 | — | 正常 |
| 401 | `.unauthorized` | トークン設定を見直す案内（未認証運用では起きない） |
| 403 or 429 かつ `x-ratelimit-remaining == 0` | `.rateLimited(resetAt:)` | 残り時間を出す。**自動再試行しない** |
| 403（上記以外） | `.unknown` | 汎用エラー（`User-Agent` 欠落など実装不備の可能性） |
| 404 | `.notFound` | 「見つかりませんでした」 |
| 422 | `.invalidQuery(reason:)` | 検索語の見直し案内（`errors[0].message` を `reason` に入れる） |
| 500〜599 | `.server(status:)` | 「時間をおいて再試行」 |
| 上記以外の非 2xx | `.unknown` | 汎用エラー |
| `JSONDecoder` の失敗 | `.decoding` | 汎用エラー（**握りつぶさずログに残す**） |

- **写像は Repository 層の1関数に閉じる**（`HTTPResponse -> GitHubError`）。
  UseCase / ViewModel でステータスコードを見ない
- `.decoding` を `.unknown` にまとめない。**API の変更に気づける唯一の信号**であるため

---

## 5. アクセストークン（任意）

未認証で完結するが、開発中にレート制限へ当たりやすいため**任意で読み込めるようにする**。

- 供給元は **`.xcconfig` に書いた `GITHUB_TOKEN`**（`.gitignore` 済み）か、環境変数（テスト・CI用）
- **リポジトリにコミットしない**（INV-7）。`.xcconfig.sample` だけを置く
- 値があれば `Authorization: Bearer <token>` を付ける。無ければ**ヘッダごと付けない**
  （空の `Authorization` を送ると 401 になる）
- トークンの有無は **`Core` の `HTTPClient` の外**で決め、`Repository` が組み立てる
- **本番アプリでこの方式を採ってはならない**ことを README に明記する
  （バンドルに埋めたトークンは取り出せる。サンプル専用の割り切りである）

---

## 6. テスト用の固定応答

`TestSupport` に、**実際の API 応答をそのまま切り出した JSON** を置く（`Fixtures/`）。

| ファイル | 中身 |
|---|---|
| `search_repositories_ok.json` | 30件・`total_count` 大 |
| `search_repositories_empty.json` | 0件 |
| `search_repositories_last_page.json` | 12件（`per_page` 未満 ＝ 最終ページ） |
| `repo_detail_ok.json` | ライセンス・トピックあり |
| `repo_detail_no_license.json` | `license: null`・`topics: []`（**null 許容の確認**） |
| `error_422_validation.json` | `errors[0].message` あり |
| `error_403_rate_limit.json` | ヘッダ込み（`x-ratelimit-remaining: 0`） |

> **手で書いたサンプルではなく実応答を使う**。手書きは「自分が想定した形」しか含まず、
> `license: null` のような**実際に来る形**を落とすため。
