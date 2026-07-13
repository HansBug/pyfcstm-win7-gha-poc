#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "usage: $0 RESULTS_IMAGE EXPECTED_PYFCSTM_SHA256 EXPECTED_FCSTM_GUI_SHA256 OUTPUT_DIRECTORY" >&2
    exit 64
fi

results_image=$1
expected_pyfcstm_sha256=${2^^}
expected_fcstm_gui_sha256=${3^^}
output_directory=$4
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

for evidence_file in fcstm-gui-hash.txt pyfcstm-verify.log fcstm-gui-self-check.log \
    fcstm-gui-self-check.json java-version-guest.txt build-metadata.txt \
    fcstm-gui-build-metadata.txt ucrt-install.log; do
    if mcopy -o -i "$results_volume" "::$evidence_file" "$output_directory/$evidence_file"; then
        normalize_text_file "$output_directory/$evidence_file"
    fi
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

[[ -f "$output_directory/fcstm-gui-hash.txt" ]] || {
    echo "guest fcstm-gui hash report is missing" >&2
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
[[ -f "$output_directory/fcstm-gui-self-check.json" ]] || {
    echo "guest fcstm-gui self-check report is missing" >&2
    exit 1
}
grep -F '"status": "passed"' "$output_directory/fcstm-gui-self-check.json" >/dev/null || {
    echo "guest fcstm-gui self-check report was not passed" >&2
    exit 1
}
grep -F '"passed": 182' "$output_directory/fcstm-gui-self-check.json" >/dev/null || {
    echo "guest fcstm-gui self-check report did not contain 182 passed checks" >&2
    exit 1
}

printf 'Windows 7 SP1 guest passed. pyfcstm SHA-256: %s\n' "$actual_pyfcstm_sha256"
printf 'Windows 7 SP1 guest passed. fcstm-gui SHA-256: %s\n' "$actual_fcstm_gui_sha256"
