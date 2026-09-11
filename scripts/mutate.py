#!/usr/bin/env python3
"""変異を1つずつ当て、狙った TS が死ぬかを確かめる。

scripts/mutation-test.sh から呼ばれる。単体では使わない
（隔離コピーの用意と後始末は呼び出し側の仕事である）。

  使い方: mutate.py <隔離コピー> <カタログ> [変異ID ...]
"""
import json
import os
import re
import subprocess
import sys

# 変異を当てるとテストが「赤」ではなく「止まったまま」になることがある
# （通知を消すと await iterator.next() が永久に待つ・docs/04 §6-3-2）。
# 打ち切って「止まった」と報告する。ここで待ち続けると、何が壊れたか分からない。
TIMEOUT_SECONDS = 600


def run_tests(root):
    """テストを走らせ、(赤になったテスト名, 打ち切ったか, ビルドできたか) を返す。"""
    try:
        out = subprocess.run(
            ["swift", "test"], cwd=root, capture_output=True, text=True, timeout=TIMEOUT_SECONDS
        )
    except subprocess.TimeoutExpired:
        subprocess.run(["pkill", "-f", "GitHubSamplePackageTests"], capture_output=True)
        return set(), True, True

    blob = out.stdout + out.stderr
    if re.search(r"^/.*: error: ", blob, re.M):
        return set(), False, False
    return set(re.findall(r'Test "([^"]+)" (?:recorded an issue|failed)', blob)), False, True


def ts_numbers(names):
    return {m.group(1) for n in names if (m := re.match(r"(TS-[0-9]+[a-z]?)", n))}


def apply_mutation(root, mutation):
    path = os.path.join(root, mutation["file"])
    with open(path) as handle:
        source = handle.read()
    if mutation["old"] not in source:
        return False
    with open(path, "w") as handle:
        handle.write(source.replace(mutation["old"], mutation["new"], 1))
    return True


def restore(root, mutation):
    subprocess.run(["git", "checkout", "--", mutation["file"]], cwd=root, check=True)


def main():
    root, catalogue_path = sys.argv[1], sys.argv[2]
    wanted = set(sys.argv[3:])

    with open(catalogue_path) as handle:
        mutations = json.load(handle)["mutations"]
    if wanted:
        mutations = [m for m in mutations if m["id"] in wanted]

    failures = []
    for mutation in mutations:
        label = f'{mutation["id"]} [{mutation["ac"]}] {mutation["label"]}'
        if not apply_mutation(root, mutation):
            print(f"✗ {label}\n    置換対象が見つからない（カタログが実装とずれている）")
            failures.append(mutation["id"])
            continue

        red, timed_out, built = run_tests(root)
        restore(root, mutation)

        expected = set(mutation.get("expects", []))
        actual = ts_numbers(red)

        if not built:
            print(f"✗ {label}\n    ビルドできない（変異が型を壊している。当て方を直すこと）")
            failures.append(mutation["id"])
        elif timed_out:
            print(f"✗ {label}\n    **止まったまま**になった。赤で落ちる形に直すこと（docs/04 §6-3-2）")
            failures.append(mutation["id"])
        elif not expected:
            if actual:
                print(f"✓ {label}\n    生き残るはずが死んだ: {' '.join(sorted(actual))}")
                print("      → カタログの reason が古い。読み直すこと")
            else:
                print(f"✓ {label}\n    生き残った（等価変異として想定どおり）")
        elif missing := expected - actual:
            print(f"✗ {label}\n    死ぬはずの TS が生きている: {' '.join(sorted(missing))}")
            if actual:
                print(f"      （代わりに死んだ: {' '.join(sorted(actual))}）")
            failures.append(mutation["id"])
        else:
            extra = actual - expected
            note = f"（ほかに {' '.join(sorted(extra))} も）" if extra else ""
            print(f"✓ {label}\n    死んだ: {' '.join(sorted(expected))} {note}")

    print()
    print(f"変異 {len(mutations)} 件 / 問題 {len(failures)} 件"
          + (f": {' '.join(failures)}" if failures else ""))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
