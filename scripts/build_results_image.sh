#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 OUTPUT_IMAGE" >&2
    exit 64
fi

output_image=$1
partition_start_sector=2048

mkdir -p "$(dirname "$output_image")"
truncate -s 64M "$output_image"
printf 'label: dos\nunit: sectors\n\nstart=%s, type=c, bootable\n' "$partition_start_sector" |
    sfdisk --no-reread --no-tell-kernel "$output_image" >/dev/null
mformat -i "${output_image}@@$((partition_start_sector * 512))" -F -v PYFCSTMRES ::
