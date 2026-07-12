#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "usage: $0 PAYLOAD_DIRECTORY OUTPUT_ISO WIN7_IMAGE_INDEX WIN7_LOCALE" >&2
    exit 64
fi

payload_directory=$1
output_iso=$2
image_index=$3
locale=$4
repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

[[ -d "$payload_directory" ]] || {
    echo "payload directory does not exist: $payload_directory" >&2
    exit 66
}
[[ "$image_index" =~ ^[1-9][0-9]*$ ]] || {
    echo "Windows image index must be a positive integer" >&2
    exit 64
}
[[ "$locale" =~ ^[[:alpha:]]{2,3}-[[:alpha:]]{2,4}$ ]] || {
    echo "Windows locale must use a language-region form such as en-US or zh-CN" >&2
    exit 64
}

for required_file in api-ms-win-core-sysinfo-l1-2-0.dll pyfcstm.exe smt-verify.fcstm build-metadata.txt; do
    [[ -f "$payload_directory/$required_file" ]] || {
        echo "payload is missing $required_file" >&2
        exit 66
    }
done

staging_directory=$(mktemp -d)
cleanup() {
    rm -rf "$staging_directory"
}
trap cleanup EXIT

sed \
    -e "s/__WIN7_IMAGE_INDEX__/$image_index/g" \
    -e "s/__WIN7_LOCALE__/$locale/g" \
    "$repository_root/guest/Autounattend.xml" > "$staging_directory/Autounattend.xml"
cp "$repository_root/guest/run-ci.cmd" "$staging_directory/run-ci.cmd"
cp "$repository_root/guest/install-hook.cmd" "$staging_directory/install-hook.cmd"
cp "$repository_root/guest/verify-cli.cmd" "$staging_directory/verify-cli.cmd"
cp "$payload_directory/api-ms-win-core-sysinfo-l1-2-0.dll" "$staging_directory/api-ms-win-core-sysinfo-l1-2-0.dll"
cp "$payload_directory/pyfcstm.exe" "$staging_directory/pyfcstm.exe"
cp "$payload_directory/smt-verify.fcstm" "$staging_directory/smt-verify.fcstm"
cp "$payload_directory/build-metadata.txt" "$staging_directory/build-metadata.txt"

mkdir -p "$(dirname "$output_iso")"
xorriso -as mkisofs \
    -iso-level 3 \
    -J \
    -joliet-long \
    -V PYFCSTM_PAYLOAD \
    -o "$output_iso" \
    "$staging_directory" >/dev/null
