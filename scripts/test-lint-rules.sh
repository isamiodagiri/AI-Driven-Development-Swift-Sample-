#!/usr/bin/env bash
#
# test-lint-rules.sh — .swiftlint.yml の custom_rules 自身の検収。
#
# 「違反コードを一時的に注入して落ちることを確かめ、除去する」を自動化したもの。
# ルールが空振りしていても CI は緑に見えるため、ルールを足したら必ずここにも1件足す。
#
#   使い方: ./scripts/test-lint-rules.sh
#
# SwiftLint 本体があればそれを使い、無ければ scripts/swiftlint_sim.py（custom_rules の
# 意味論だけを再現した簡易チェッカー）で代替する。代替で緑になっても、
# **本物の SwiftLint で確かめるまでは検収は完了していない**（docs/01-architecture.md §9-3）。
#
set -uo pipefail
cd "$(dirname "$0")/.."
CONFIG="$PWD/.swiftlint.yml"

if command -v swiftlint >/dev/null 2>&1; then
  ENGINE="swiftlint"
  run_lint() { (cd "$1" && cp "$CONFIG" .swiftlint.yml && swiftlint lint --strict --quiet 2>&1); }
else
  ENGINE="simulator"
  run_lint() { python3 "$PWD/scripts/swiftlint_sim.py" "$CONFIG" "$1" 2>&1; }
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
passed=0; failed=0

make_clean_tree() { # $1=行き先
  local d="$1/Sources"
  mkdir -p "$d/Core/HTTP" "$d/Domain/Entity" \
           "$d/Repository/RepoRepository" "$d/Repository/FavoriteRepository" \
           "$d/UseCase" "$d/SearchFeature/View" "$d/SearchFeature/ViewModel" "$d/SearchFeature/State"

  cat > "$d/Core/HTTP/URLSessionHTTPClient.swift" <<'EOF'
import Foundation
public struct URLSessionHTTPClient: HTTPClient, Sendable {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
}
EOF
  cat > "$d/Domain/Entity/RepoSummary.swift" <<'EOF'
public struct RepoSummary: Equatable, Sendable, Identifiable {
    public let id: Int
    public let fullName: String
}
EOF
  cat > "$d/Repository/RepoRepository/RepoRepositoryImpl.swift" <<'EOF'
import Domain
public protocol RepoRepository: Sendable {
    func search(query: String, page: Int) async throws -> [RepoSummary]
}
public final class RepoRepositoryImpl: RepoRepository, Sendable {
    private let client: HTTPClient
    public init(client: HTTPClient) { self.client = client }
}
EOF
  cat > "$d/Repository/FavoriteRepository/FavoriteRepositoryImpl.swift" <<'EOF'
import Domain
import Foundation
public protocol FavoriteRepository: Sendable {
    func favorites() async -> [RepoSummary]
}
public actor FavoriteRepositoryImpl: FavoriteRepository {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
}
EOF
  cat > "$d/UseCase/SearchReposUseCase.swift" <<'EOF'
import Domain
import Repository
public struct SearchReposUseCase: Sendable {
    private let repository: any RepoRepository
    public init(repository: any RepoRepository) { self.repository = repository }
}
EOF
  cat > "$d/SearchFeature/ViewModel/SearchViewModel.swift" <<'EOF'
import Combine
import Domain
import UseCase
@MainActor
public final class SearchViewModel: ObservableObject {
    @Published public private(set) var state = SearchState(title: "")
    private let searchRepos: SearchReposUseCase
    public init(searchRepos: SearchReposUseCase) { self.searchRepos = searchRepos }
}
EOF
  cat > "$d/SearchFeature/View/SearchScreen.swift" <<'EOF'
import DesignSystem
import SwiftUI
public struct SearchScreen: View {
    @StateObject private var viewModel: SearchViewModel
    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text(viewModel.state.title).foregroundStyle(AppColor.textPrimary)
        }
    }
}
EOF
  cat > "$d/SearchFeature/State/SearchState.swift" <<'EOF'
public struct SearchState: Equatable, Sendable {
    public var title: String
}
EOF
}

expect_clean() {
  local dir="$WORK/clean"; rm -rf "$dir"; mkdir -p "$dir"; make_clean_tree "$dir"
  if out=$(run_lint "$dir"); then
    echo "✓ 正しいツリーで違反 0 件"; passed=$((passed+1))
  else
    echo "✗ 正しいツリーなのに落ちた:"; echo "$out" | sed 's/^/      /'; failed=$((failed+1))
  fi
}

expect_violation() { # $1=不変条件ID $2=説明 $3=注入するファイル(相対) $4=注入する行
  local dir="$WORK/case_$$_$RANDOM"; mkdir -p "$dir"; make_clean_tree "$dir"
  printf '%s\n' "$4" >> "$dir/Sources/$3"
  out=$(run_lint "$dir"); code=$?
  if [ "$code" -ne 0 ] && echo "$out" | grep -q "$1 "; then
    echo "✓ $1 を検出: $2"; passed=$((passed+1))
  else
    echo "✗ $1 を検出できなかった: $2 (exit=$code)"; echo "$out" | sed 's/^/      /'; failed=$((failed+1))
  fi
  rm -rf "$dir"
}

echo "== .swiftlint.yml custom_rules の検収（違反注入）=="
echo "   検査エンジン: $ENGINE"
[ "$ENGINE" = simulator ] && echo "   ※ SwiftLint 本体が無いため簡易チェッカーで代替している（本物での検収は M1 で行う）"
echo
expect_clean

expect_violation INV-3  "UseCase が URLSession を触る" \
  "UseCase/SearchReposUseCase.swift" 'let s = URLSession.shared'
expect_violation INV-3  "UseCase が UserDefaults を触る" \
  "UseCase/SearchReposUseCase.swift" 'let d = UserDefaults.standard'
expect_violation INV-4  "@unchecked Sendable を書く" \
  "Core/HTTP/URLSessionHTTPClient.swift" 'final class Cache: @unchecked Sendable {}'
expect_violation INV-5  "State が Domain を参照する" \
  "SearchFeature/State/SearchState.swift" 'import Domain'
expect_violation INV-6  "View に寸法を直書きする" \
  "SearchFeature/View/SearchScreen.swift" 'let pad = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)'
expect_violation INV-9  "View が2つ目の ViewModel を参照する" \
  "SearchFeature/View/SearchScreen.swift" 'private let other: FavoriteViewModel? = nil'
expect_violation INV-9  "View が UseCase を直接参照する" \
  "SearchFeature/View/SearchScreen.swift" 'private let uc: SearchReposUseCase? = nil'
expect_violation INV-10 "View が並べ替えを行う" \
  "SearchFeature/View/SearchScreen.swift" 'let sorted = items.sorted(by: { $0.id < $1.id })'
expect_violation INV-10 "View が await を書く" \
  "SearchFeature/View/SearchScreen.swift" 'func load() async { await viewModel.load() }'
expect_violation INV-11 "ViewModel が他の ViewModel を参照する" \
  "SearchFeature/ViewModel/SearchViewModel.swift" 'private let favorite: FavoriteViewModel? = nil'
expect_violation INV-12 "UseCase が他の UseCase を参照する" \
  "UseCase/SearchReposUseCase.swift" 'private let loadMore: LoadMoreReposUseCase? = nil'
expect_violation INV-13 "Repository が他の Repository を参照する" \
  "Repository/RepoRepository/RepoRepositoryImpl.swift" 'private let favorite: (any FavoriteRepository)? = nil'

echo
echo "成功 $passed 件 / 失敗 $failed 件"
[ "$failed" -eq 0 ]
