#!/usr/bin/env python3
"""Remove host-SDK UCRT binaries from a generated PyInstaller spec."""

import sys
from pathlib import Path


MARKERS = (
    "\n# Use compressed PYZ archive\n",
    "\n# Use compressed PYZ archive.\n",
)
FILTER = """
# The Win7 guest installs Microsoft's KB3118401 UCRT update centrally.  Do not
# embed the hosted runner's newer UCRT/API-set forwarders in the executable.
a.binaries = [
    entry
    for entry in a.binaries
    if entry[0].lower() != "ucrtbase.dll"
    and not entry[0].lower().startswith("api-ms-win-")
]
"""


def main() -> int:
    """Insert the UCRT exclusion into a generated spec file."""
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} SPEC_FILE", file=sys.stderr)
        return 64

    spec_file = Path(sys.argv[1])
    content = spec_file.read_text(encoding="utf-8")
    if FILTER.strip() in content:
        return 0
    matching_markers = [marker for marker in MARKERS if content.count(marker) == 1]
    if len(matching_markers) != 1:
        print(f"could not locate the generated-PYZ marker in {spec_file}", file=sys.stderr)
        return 65

    marker = matching_markers[0]
    spec_file.write_text(content.replace(marker, "\n" + FILTER + marker), encoding="utf-8")
    print(f"excluded hosted-runner UCRT/API-set binaries from {spec_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
