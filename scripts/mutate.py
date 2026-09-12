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


def unmet(expected, names):
    """死ぬはずだったのに生きているものを返す。

    expects には TS 番号のほか、**テスト名の先頭**も書ける
    （TS を持たないテストが観測点になっていることがあるため）。
    """
    return {e for e in expected if not any(n.startswith(e) for n in names)}


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

        if not built:
            print(f"✗ {label}\n    ビルドできない（変異が型を壊している。当て方を直すこと）")
            failures.append(mutation["id"])
        elif timed_out:
            print(f"✗ {label}\n    **止まったまま**になった。赤で落ちる形に直すこと（docs/04 §6-3-2）")
            failures.append(mutation["id"])
        elif not expected:
            # expects が空のものは2種類ある。kind がどちらかを言う。
            #   equivalent = 振る舞いが変わっていないので、死なないのが正しい
            #   gap        = 振る舞いは変わったのに、見ているテストが無い
            kind = mutation.get("kind", "equivalent")
            if red:
                print(f"✓ {label}\n    生き残るはずが死んだ: {' '.join(sorted(red))}")
                print("      → カタログの reason が古い。読み直すこと")
            elif kind == "gap":
                print(f"✗ {label}\n    生き残った（**観測点が無い**。テストを足すこと）")
                failures.append(mutation["id"])
            else:
                print(f"✓ {label}\n    生き残った（等価変異として想定どおり）")
        elif missing := unmet(expected, red):
            print(f"✗ {label}\n    死ぬはずのテストが生きている: {' '.join(sorted(missing))}")
            if red:
                print(f"      （代わりに死んだ: {' '.join(sorted(red))}）")
            failures.append(mutation["id"])
        else:
            print(f"✓ {label}\n    死んだ: {' '.join(sorted(expected))}"
                  + (f"（赤 {len(red)} 件）" if len(red) > len(expected) else ""))

    print()
    print(f"変異 {len(mutations)} 件 / 問題 {len(failures)} 件"
          + (f": {' '.join(failures)}" if failures else ""))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
