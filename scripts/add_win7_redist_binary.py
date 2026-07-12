#!/usr/bin/env python3
"""Add one Visual C++ Redistributable DLL to a generated PyInstaller spec."""

import sys
from pathlib import Path


MARKER = "\n# Use compressed PYZ archive\n"


def main() -> int:
    """Insert one validated Redist binary into the generated spec."""
    if len(sys.argv) != 3:
        print(f"usage: {Path(sys.argv[0]).name} SPEC_FILE REDIST_DLL", file=sys.stderr)
        return 64

    spec_file = Path(sys.argv[1])
    binary_file = Path(sys.argv[2])
    if not binary_file.is_file():
        print(f"Redistributable DLL does not exist: {binary_file}", file=sys.stderr)
        return 66

    content = spec_file.read_text(encoding="utf-8")
    source = str(binary_file)
    addition = (
        f'\na.binaries.append(({binary_file.name!r}, {source!r}, "BINARY"))\n'
    )
    if addition in content:
        print(f"Redist DLL is already present in {spec_file}: {binary_file.name}", file=sys.stderr)
        return 65
    if content.count(MARKER) != 1:
        print(f"could not locate the generated-PYZ marker in {spec_file}", file=sys.stderr)
        return 65

    spec_file.write_text(content.replace(MARKER, addition + MARKER), encoding="utf-8")
    print(f"added {binary_file.name} from the Visual C++ Redist to {spec_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
