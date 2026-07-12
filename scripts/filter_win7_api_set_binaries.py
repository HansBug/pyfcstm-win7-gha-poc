#!/usr/bin/env python3
"""Remove Windows 10 API-set stubs from a generated PyInstaller spec."""

import sys
from pathlib import Path


MARKER = "\n# Use compressed PYZ archive\n"
FILTER = """
# Windows 10 exposes physical api-ms-win-core stubs in System32\\downlevel.
# They are OS API-set forwarders, not redistributable application dependencies;
# bundling them prevents a clean Windows 7 SP1 guest from starting the one-file
# executable. Keep api-ms-win-crt and the Universal CRT binaries intact.
a.binaries[:] = [
    entry
    for entry in a.binaries
    if not entry[0].replace('\\\\', '/').rsplit('/', 1)[-1]
    .lower()
    .startswith('api-ms-win-core-')
]
"""


def main() -> int:
    """Insert the binary filter into one generated PyInstaller spec file."""
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} SPEC_FILE", file=sys.stderr)
        return 64

    spec_file = Path(sys.argv[1])
    content = spec_file.read_text(encoding="utf-8")
    if FILTER in content:
        print(f"legacy API-set filter is already present in {spec_file}", file=sys.stderr)
        return 65
    if content.count(MARKER) != 1:
        print(f"could not locate the generated-PYZ marker in {spec_file}", file=sys.stderr)
        return 65

    spec_file.write_text(content.replace(MARKER, FILTER + MARKER), encoding="utf-8")
    print(f"inserted Windows 7 API-set filter into {spec_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
