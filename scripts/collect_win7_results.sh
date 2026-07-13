#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "usage: $0 RESULTS_IMAGE EXPECTED_EXE_SHA256 OUTPUT_DIRECTORY" >&2
    exit 64
fi

results_image=$1
expected_exe_sha256=${2^^}
output_directory=$3
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
[[ "$expected_exe_sha256" =~ ^[A-F0-9]{64}$ ]] || {
    echo "expected executable SHA-256 is invalid" >&2
    exit 64
}

rm -rf "$output_directory"
mkdir -p "$output_directory"
for evidence_file in result.txt failure.txt os.txt hash.txt verify-cli.log ucrt-install.log; do
    mcopy -o -i "$results_volume" "::$evidence_file" "$output_directory/$evidence_file"
    normalize_text_file "$output_directory/$evidence_file"
done

if mcopy -o -i "$results_volume" ::run-ci-started.txt "$output_directory/run-ci-started.txt"; then
    normalize_text_file "$output_directory/run-ci-started.txt"
fi

grep -Fx 'PASS' "$output_directory/result.txt" >/dev/null
grep -E '^Caption=.*Windows 7' "$output_directory/os.txt" >/dev/null
grep -Fx 'Version=6.1.7601' "$output_directory/os.txt" >/dev/null
grep -Fx 'BuildNumber=7601' "$output_directory/os.txt" >/dev/null
grep -Fx 'ServicePackMajorVersion=1' "$output_directory/os.txt" >/dev/null
grep -Fx 'ProductType=1' "$output_directory/os.txt" >/dev/null
grep -E '^OSArchitecture=(64-bit|64 位)' "$output_directory/os.txt" >/dev/null

actual_exe_sha256=$(grep -Eio '[A-F0-9]{64}' "$output_directory/hash.txt" | head -n 1 | tr '[:lower:]' '[:upper:]')
[[ "$actual_exe_sha256" == "$expected_exe_sha256" ]] || {
    echo "guest executable hash did not match the Windows build artifact" >&2
    exit 1
}

printf 'Windows 7 SP1 guest passed. Executable SHA-256: %s\n' "$actual_exe_sha256"
