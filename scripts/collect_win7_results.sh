#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 && $# -ne 5 ]]; then
    echo "usage: $0 RESULTS_IMAGE EXPECTED_PYFCSTM_SHA256 EXPECTED_FCSTM_GUI_SHA256 OUTPUT_DIRECTORY [QEMU_WORK_DIRECTORY]" >&2
    exit 64
fi

results_image=$1
expected_pyfcstm_sha256=${2^^}
expected_fcstm_gui_sha256=${3^^}
output_directory=$4
qemu_work_directory=${5:-}
results_volume="${results_image}@@1048576"

normalize_text_file() {
    local file=$1
    local bom

    bom=$(od -An -tx1 -N2 "$file" | tr -d ' \n')
    if [[ "$bom" == "fffe" || "$bom" == "feff" ]]; then
        local normalized_file="${file}.utf8"
        iconv -f UTF-16 -t UTF-8 "$file" > "$normalized_file"
        mv "$normalized_file" "$file"
    fi
    sed -i 's/\r$//' "$file"
}

[[ -f "$results_image" ]] || {
    echo "results image does not exist: $results_image" >&2
    exit 66
}
[[ "$expected_pyfcstm_sha256" =~ ^[A-F0-9]{64}$ ]] || {
    echo "expected pyfcstm executable SHA-256 is invalid" >&2
    exit 64
}
[[ "$expected_fcstm_gui_sha256" =~ ^[A-F0-9]{64}$ ]] || {
    echo "expected fcstm-gui executable SHA-256 is invalid" >&2
    exit 64
}

rm -rf "$output_directory"
mkdir -p "$output_directory"
for evidence_file in result.txt failure.txt os.txt hash.txt; do
    mcopy -o -i "$results_volume" "::$evidence_file" "$output_directory/$evidence_file"
    normalize_text_file "$output_directory/$evidence_file"
done

for evidence_file in system-stage.txt gui-stage.txt run-ci-started.txt gui-task-started.txt     fcstm-gui-hash.txt pyfcstm-verify.log pyfcstm-self-check.txt     pyfcstm-self-check-commands.log fcstm-gui-self-check.log     fcstm-gui-self-check.json java-version-guest.txt build-metadata.txt     fcstm-gui-build-metadata.txt ucrt-install.log gui-task-create.log; do
    mcopy -o -i "$results_volume" "::$evidence_file" "$output_directory/$evidence_file"
    normalize_text_file "$output_directory/$evidence_file"
done

for evidence_file in fcstm-gui-acceptance.json     fcstm-gui-acceptance.stdout.log fcstm-gui-acceptance.stderr.log     run-gui-acceptance.log gui-session.txt desktop-before.png desktop-before.txt     desktop-gui-visible.png desktop-gui-visible.txt desktop-after.png desktop-after.txt; do
    mcopy -o -i "$results_volume" "::$evidence_file" "$output_directory/$evidence_file"
    case "$evidence_file" in
        *.txt|*.log|*.json) normalize_text_file "$output_directory/$evidence_file" ;;
    esac
done

mkdir -p "$output_directory/fcstm-gui-acceptance-artifacts"
mcopy -s -o -i "$results_volume" ::fcstm-gui-acceptance-artifacts "$output_directory/"

grep -Fx 'PASS' "$output_directory/result.txt" >/dev/null
grep -Fx 'PASS' "$output_directory/system-stage.txt" >/dev/null
grep -Fx 'PASS' "$output_directory/gui-stage.txt" >/dev/null
grep -Fx 'started' "$output_directory/gui-task-started.txt" >/dev/null
grep -E '^Caption=.*Windows 7' "$output_directory/os.txt" >/dev/null
grep -Fx 'Version=6.1.7601' "$output_directory/os.txt" >/dev/null
grep -Fx 'BuildNumber=7601' "$output_directory/os.txt" >/dev/null
grep -Fx 'ServicePackMajorVersion=1' "$output_directory/os.txt" >/dev/null
grep -Fx 'ProductType=1' "$output_directory/os.txt" >/dev/null
grep -E '^OSArchitecture=(64-bit|64 位)' "$output_directory/os.txt" >/dev/null

grep -Fx 'status=passed' "$output_directory/pyfcstm-self-check.txt" >/dev/null
grep -Fx 'total=15' "$output_directory/pyfcstm-self-check.txt" >/dev/null
grep -Fx 'passed=15' "$output_directory/pyfcstm-self-check.txt" >/dev/null
grep -Fx 'failed=0' "$output_directory/pyfcstm-self-check.txt" >/dev/null

extract_sha256() {
    local report=$1
    awk '
    {
        line = $0
        gsub(/[^0-9A-Fa-f]/, "", line)
        if (length(line) == 64) {
            print toupper(line)
            exit
        }
    }
' "$report"
}

actual_pyfcstm_sha256=$(extract_sha256 "$output_directory/hash.txt")
[[ "$actual_pyfcstm_sha256" =~ ^[A-F0-9]{64}$ ]] || {
    echo "guest pyfcstm hash report did not contain a 256-bit digest" >&2
    exit 1
}
[[ "$actual_pyfcstm_sha256" == "$expected_pyfcstm_sha256" ]] || {
    echo "guest pyfcstm hash did not match the Windows build artifact" >&2
    exit 1
}

actual_fcstm_gui_sha256=$(extract_sha256 "$output_directory/fcstm-gui-hash.txt")
[[ "$actual_fcstm_gui_sha256" =~ ^[A-F0-9]{64}$ ]] || {
    echo "guest fcstm-gui hash report did not contain a 256-bit digest" >&2
    exit 1
}
[[ "$actual_fcstm_gui_sha256" == "$expected_fcstm_gui_sha256" ]] || {
    echo "guest fcstm-gui hash did not match the Windows build artifact" >&2
    exit 1
}

grep -F '"status": "passed"' "$output_directory/fcstm-gui-self-check.json" >/dev/null
grep -F '"passed": 182' "$output_directory/fcstm-gui-self-check.json" >/dev/null
grep -F '"failed": 0' "$output_directory/fcstm-gui-self-check.json" >/dev/null
test -s "$output_directory/java-version-guest.txt"
test -s "$output_directory/build-metadata.txt"
test -s "$output_directory/fcstm-gui-build-metadata.txt"

python3 - "$output_directory" <<'PY'
import hashlib
import json
import pathlib
import struct
import sys

root = pathlib.Path(sys.argv[1])


def png_info(path):
    data = path.read_bytes()
    if len(data) < 32 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("invalid PNG signature: {}".format(path))
    if data[12:16] != b"IHDR":
        raise SystemExit("PNG has no IHDR: {}".format(path))
    width, height = struct.unpack(">II", data[16:24])
    if width < 640 or height < 480 or len(data) < 1000 or len(set(data[32:])) < 8:
        raise SystemExit("desktop PNG is blank or too small: {}".format(path))
    return width, height


def parse_key_values(path):
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    return values


session = parse_key_values(root / "gui-session.txt")
for key, expected in {
    "user": "ci",
    "qt_qpa_platform": "windows",
    "window_visible": "true",
    "process_has_exited": "True",
}.items():
    if session.get(key) != expected:
        raise SystemExit("GUI session {}={!r}, expected {!r}".format(key, session.get(key), expected))
for key in ("session_id", "process_id", "window_process_id", "window_handle", "acceptance_exit_code"):
    if not session.get(key, "").isdigit():
        raise SystemExit("GUI session field is not numeric: {}".format(key))
if int(session["window_handle"]) <= 0 or session["acceptance_exit_code"] != "0":
    raise SystemExit("GUI session did not record a visible successful process")
if int(session["window_process_id"]) != int(session["process_id"]):
    raise SystemExit("GUI window belongs to a different process")

self_check = json.loads((root / "fcstm-gui-self-check.json").read_text(encoding="utf-8"))
if self_check.get("status") != "passed":
    raise SystemExit("GUI self-check status is not passed")
self_check_counts = self_check.get("counts", {})
for key, expected in {"total": 182, "passed": 182, "failed": 0}.items():
    if self_check_counts.get(key) != expected:
        raise SystemExit("GUI self-check count {}={!r}, expected {!r}".format(
            key, self_check_counts.get(key), expected
        ))

report_path = root / "fcstm-gui-acceptance.json"
report = json.loads(report_path.read_text(encoding="utf-8"))
if report.get("status") != "passed":
    raise SystemExit("interactive acceptance status is not passed")
if report.get("counts") != {"total": 140, "passed": 140, "failed": 0}:
    raise SystemExit("interactive acceptance counts are wrong: {}".format(report.get("counts")))
if report.get("platform", {}).get("qt_platform") != "windows":
    raise SystemExit("interactive acceptance did not use the Windows QPA platform")

artifact_root = root / "fcstm-gui-acceptance-artifacts"
artifacts = report.get("artifacts")
if not isinstance(artifacts, list) or not artifacts:
    raise SystemExit("interactive acceptance artifact inventory is empty")
png_count = 0
for item in artifacts:
    relative = item.get("path")
    if not relative:
        raise SystemExit("acceptance artifact has no path")
    path = artifact_root / relative
    if not path.is_file():
        raise SystemExit("acceptance artifact is missing: {}".format(relative))
    data = path.read_bytes()
    if len(data) != item.get("size") or hashlib.sha256(data).hexdigest() != item.get("sha256"):
        raise SystemExit("acceptance artifact digest mismatch: {}".format(relative))
    if path.suffix.lower() == ".png":
        png_count += 1
if png_count < 3:
    raise SystemExit("interactive acceptance produced too few PNG artifacts")

for name in ("desktop-before.png", "desktop-gui-visible.png", "desktop-after.png"):
    width, height = png_info(root / name)
    print("{}: {}x{}".format(name, width, height))

desktop_hashes = [
    hashlib.sha256((root / name).read_bytes()).hexdigest()
    for name in ("desktop-before.png", "desktop-gui-visible.png", "desktop-after.png")
]
if len(set(desktop_hashes)) == 1:
    raise SystemExit("desktop screenshots did not change across GUI lifecycle")

print("interactive GUI evidence: 140/140, {} artifacts, {} PNGs".format(len(artifacts), png_count))
PY

if [[ -n "$qemu_work_directory" ]]; then
    [[ -d "$qemu_work_directory" ]] || {
        echo "QEMU work directory does not exist: $qemu_work_directory" >&2
        exit 1
    }
    mkdir -p "$output_directory/qemu-screens"
    for qemu_file in qemu-screen.ppm qemu.stderr.log qemu-acceleration.txt; do
        [[ -f "$qemu_work_directory/$qemu_file" ]] || {
            echo "QEMU evidence file is missing: $qemu_file" >&2
            exit 1
        }
        cp "$qemu_work_directory/$qemu_file" "$output_directory/$qemu_file"
    done
    grep -E '^mode=(kvm|tcg)$' "$output_directory/qemu-acceleration.txt" >/dev/null || {
        echo "QEMU acceleration evidence is invalid" >&2
        exit 1
    }
    shopt -s nullglob
    qemu_frames=("$qemu_work_directory"/qemu-screens/*.ppm)
    if (( ${#qemu_frames[@]} == 0 )); then
        echo "QEMU screenshot ring is empty" >&2
        exit 1
    fi
    cp "${qemu_frames[@]}" "$output_directory/qemu-screens/"
    shopt -u nullglob
    python3 - "$output_directory/qemu-screen.ppm" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
data = path.read_bytes()
match = re.match(rb"P6\s+(\d+)\s+(\d+)\s+255\s", data)
if not match:
    raise SystemExit("invalid QEMU PPM header")
width, height = map(int, match.groups())
pixels = data[match.end():]
if width < 640 or height < 480 or len(pixels) < 1000 or len(set(pixels[:100000])) < 8:
    raise SystemExit("QEMU PPM is blank or too small")
print("QEMU framebuffer: {}x{}, {} bytes".format(width, height, len(data)))
PY
fi

printf 'Windows 7 SP1 interactive GUI guest passed. pyfcstm SHA-256: %s\n' "$actual_pyfcstm_sha256"
printf 'Windows 7 SP1 interactive GUI guest passed. pyfcstm self-check: 15/15\n'
printf 'Windows 7 SP1 interactive GUI guest passed. fcstm-gui self-check: 182/182\n'
printf 'Windows 7 SP1 interactive GUI guest passed. fcstm-gui acceptance: 140/140\n'
printf 'Windows 7 SP1 interactive GUI guest passed. fcstm-gui SHA-256: %s\n' "$actual_fcstm_gui_sha256"
