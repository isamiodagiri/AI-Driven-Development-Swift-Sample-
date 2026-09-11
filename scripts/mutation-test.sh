#!/usr/bin/env bash
#
# mutation-test.sh — 変異検証（docs/04-test-strategy.md §6）。
#
# 「実装を1箇所壊すと、狙ったテストが赤になる」ことを確かめる。
# **テストが緑であることと、そのテストが落ちうることは別である。**
#
#   ./scripts/mutation-test.sh              # カタログ全件
#   ./scripts/mutation-test.sh M-10 M-17    # 指定した変異だけ
#
# 変異は git worktree の隔離コピーへ当てる。作業ツリーの未コミット変更を
# 巻き込まないためであり、途中で落ちても手元のコードは汚れない。
#
# **CI の毎回の push では回さない**（全件で 15 分ほどかかる）。
# .github/workflows/mutation.yml が週1回と手動起動で回す。
#
set -uo pipefail
cd "$(dirname "$0")/.."

CATALOGUE="$PWD/scripts/mutations.json"
WORKTREE="$(mktemp -d)/mutation"

cleanup() {
  git worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true
  rm -rf "$(dirname "$WORKTREE")"
}
trap cleanup EXIT

echo "== 変異検証（docs/04-test-strategy.md §6）=="

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "! 未コミットの変更がある。隔離コピーは HEAD から作るので、"
  echo "  いま見ている変更は検証に入らない。"
  echo ""
fi

echo "隔離コピーを作る: $WORKTREE"
git worktree add --detach "$WORKTREE" HEAD >/dev/null 2>&1 || {
  echo "✗ worktree を作れなかった"; exit 1;
}

echo "変異を当てる前に、緑であることを確かめる"
if ! (cd "$WORKTREE" && swift test >/dev/null 2>&1); then
  echo "✗ 変異を当てる前から赤である。先にテストを直すこと"
  exit 1
fi
echo ""

python3 "$PWD/scripts/mutate.py" "$WORKTREE" "$CATALOGUE" "$@"
