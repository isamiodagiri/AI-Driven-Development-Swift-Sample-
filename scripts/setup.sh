#!/bin/sh
#
# クローン直後に1回だけ実行する。
#   ./scripts/setup.sh
#
set -e
cd "$(dirname "$0")/.."

git config core.hooksPath .githooks
echo "✓ pre-commit hook を有効化した（core.hooksPath = .githooks）"

command -v swift       >/dev/null 2>&1 || echo "! swift が無い（Xcode 16 以降 / Swift 6 ツールチェーンが要る）"
command -v swiftformat >/dev/null 2>&1 || echo "! swiftformat が無い（brew install swiftformat）"
command -v swiftlint   >/dev/null 2>&1 || echo "! swiftlint が無い（brew install swiftlint）"

echo ""
echo "確認:"
echo "  swiftformat --lint .           # 整形（差分があれば落ちる）"
echo "  swiftlint --strict             # 規約（INV-3〜INV-13）"
echo "  swift test                     # テスト"
echo "  ./scripts/test-lint-rules.sh   # Lint ルールの検収"
