#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "usage: $0 OUTPUT_IMAGE WIN7_IMAGE_INDEX WIN7_LOCALE" >&2
    exit 64
fi

output_image=$1
image_index=$2
locale=$3
repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

[[ "$image_index" =~ ^[1-9][0-9]*$ ]] || {
    echo "Windows image index must be a positive integer" >&2
    exit 64
}
[[ "$locale" =~ ^[[:alpha:]]{2,3}-[[:alpha:]]{2,4}$ ]] || {
    echo "Windows locale must use a language-region form such as en-US or zh-CN" >&2
    exit 64
}

staging_directory=$(mktemp -d)
cleanup() {
    rm -rf "$staging_directory"
}
trap cleanup EXIT

sed \
    -e "s/__WIN7_IMAGE_INDEX__/$image_index/g" \
    -e "s/__WIN7_LOCALE__/$locale/g" \
    "$repository_root/guest/Autounattend.xml" > "$staging_directory/Autounattend.xml"

mkdir -p "$(dirname "$output_image")"
truncate -s 1440K "$output_image"
mkfs.fat -F 12 -n UNATTEND "$output_image" >/dev/null
mcopy -o -i "$output_image" "$staging_directory/Autounattend.xml" ::Autounattend.xml
