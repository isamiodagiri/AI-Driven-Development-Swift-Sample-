#!/usr/bin/env python3
"""SwiftLint の custom_rules を再現する簡易チェッカー。

SwiftLint 本体が入っていない環境（Linux の CI・コンテナ）で、
.swiftlint.yml の custom_rules が「意図した違反で発火し、正しいコードでは発火しない」ことを
確かめるためだけに使う。**SwiftLint 本体の代わりではない。**

再現している意味論:
  - regex は「ファイル内容の全体」に対して適用する（複数行にまたがるパターンを許す）
  - included / excluded は「ファイルパス」に対する正規表現
  - match_kinds は本PJでは使っていないので再現しない

使い方: swiftlint_sim.py <config.yml> <対象ルート>   違反があれば exit 1
"""
import re
import sys
from pathlib import Path

import yaml


def main() -> int:
    config_path, root = Path(sys.argv[1]), Path(sys.argv[2])
    rules = yaml.safe_load(config_path.read_text())["custom_rules"]

    compiled = []
    for key, rule in rules.items():
        compiled.append((
            key,
            rule.get("name", key),
            re.compile(rule["regex"]),
            re.compile(rule["included"]) if rule.get("included") else None,
            re.compile(rule["excluded"]) if rule.get("excluded") else None,
            rule.get("message", ""),
        ))

    violations = 0
    for path in sorted(root.rglob("*.swift")):
        p = str(path.resolve())
        text = path.read_text()
        for key, name, regex, included, excluded, message in compiled:
            if included and not included.search(p):
                continue
            if excluded and excluded.search(p):
                continue
            m = regex.search(text)
            if m:
                line = text.count("\n", 0, m.start()) + 1
                print(f"{p}:{line}: error: {name} — {message} ({key})")
                violations += 1

    print(f"\n違反 {violations} 件" if violations else "\n✓ 違反なし")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main())
