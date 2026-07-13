#!/usr/bin/env python3
"""Make the acceptance sanitizer work with PyInstaller 4.10.

PyInstaller 4.10 stores the pure-module code cache on ``Analysis.pure``;
newer releases also expose it through ``CONF['code_cache']``.  The acceptance
source targets both layouts, so this helper applies a narrow, idempotent patch
after the source checkout and before the generated spec imports the sanitizer.
"""

import sys
from pathlib import Path


OLD = '    code_cache = CONF["code_cache"].get(id(analysis.pure))'
NEW = (
    '    code_cache = CONF.get("code_cache", {}).get(id(analysis.pure)) '
    'or getattr(analysis.pure, "_code_cache", None)'
)


def patch(path: Path) -> bool:
    """Apply the compatibility expression and report whether it changed."""
    content = path.read_text(encoding="utf-8")
    if NEW in content:
        return False
    if content.count(OLD) != 1:
        raise RuntimeError("acceptance sanitizer cache expression was not unique")
    path.write_text(content.replace(OLD, NEW), encoding="utf-8")
    return True


def main() -> int:
    """Patch one sanitizer module supplied on the command line."""
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} SANITIZER_FILE", file=sys.stderr)
        return 64
    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"sanitizer file does not exist: {path}", file=sys.stderr)
        return 66
    changed = patch(path)
    print("PyInstaller 4.10 sanitizer compatibility: " + ("patched" if changed else "already present"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
