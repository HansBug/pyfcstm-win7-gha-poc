#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 URL OUTPUT_FILE" >&2
    exit 64
fi

url=$1
output_file=$2
chunk_size=${DOWNLOAD_CHUNK_SIZE_BYTES:-67108864}
fallback_urls=${DOWNLOAD_FALLBACK_URLS:-}

[[ "$chunk_size" =~ ^[1-9][0-9]*$ ]] || {
    echo "DOWNLOAD_CHUNK_SIZE_BYTES must be a positive integer" >&2
    exit 64
}

mkdir -p "$(dirname "$output_file")"
download_urls=("$url")
if [[ -n "$fallback_urls" ]]; then
    while IFS= read -r fallback_url; do
        [[ -n "$fallback_url" ]] && download_urls+=("$fallback_url")
    done <<< "$fallback_urls"
fi

# Several public artifact gateways reset long HTTP/2 range streams near the
# 2 GiB boundary. HTTP/1.1 range responses are stable for the selected media.
range_source=
content_length=
for candidate_url in "${download_urls[@]}"; do
    if ! headers=$(curl --http1.1 --fail --location --silent --show-error --connect-timeout 30 \
        --max-time 60 --head "$candidate_url"); then
        echo "Unable to inspect download source: $candidate_url" >&2
        continue
    fi
    candidate_length=$(printf '%s\n' "$headers" |
        awk 'tolower($1) == "content-length:" { value = $2 } END { gsub("\\r", "", value); print value }')
    accepts_ranges=$(printf '%s\n' "$headers" |
        awk 'tolower($1) == "accept-ranges:" { value = $2 } END { gsub("\\r", "", value); print tolower(value) }')
    if [[ "$candidate_length" =~ ^[1-9][0-9]*$ ]] && [[ "$accepts_ranges" == "bytes" ]]; then
        range_source=$candidate_url
        content_length=$candidate_length
        break
    fi
    echo "Download source does not provide usable byte ranges: $candidate_url" >&2
done

if [[ -z "$range_source" ]]; then
    echo "No source provides byte ranges; trying single-stream downloads." >&2
    for candidate_url in "${download_urls[@]}"; do
        temporary_file="${output_file}.part"
        rm -f "$temporary_file"
        if curl --http1.1 --fail --location --retry 5 --retry-all-errors --silent --show-error \
            --output "$temporary_file" "$candidate_url"; then
            mv "$temporary_file" "$output_file"
            exit 0
        fi
    done
    exit 1
fi

ordered_download_urls=("$range_source")
for candidate_url in "${download_urls[@]}"; do
    [[ "$candidate_url" != "$range_source" ]] && ordered_download_urls+=("$candidate_url")
done
download_urls=("${ordered_download_urls[@]}")
printf 'Using byte-range source: %s\n' "$range_source" >&2

temporary_file="${output_file}.part"
rm -f "$output_file" "$temporary_file"
offset=0
while [[ "$offset" -lt "$content_length" ]]; do
    end=$((offset + chunk_size - 1))
    if [[ "$end" -ge "$content_length" ]]; then
        end=$((content_length - 1))
    fi
    expected_size=$((end - offset + 1))
    printf 'Downloading bytes %s-%s of %s.\n' "$offset" "$end" "$content_length" >&2
    downloaded=false
    for download_url in "${download_urls[@]}"; do
        rm -f "$temporary_file"
        if ! curl --http1.1 --fail --location --retry 5 --retry-all-errors --connect-timeout 30 \
            --max-time 180 --silent --show-error --range "${offset}-${end}" \
            --output "$temporary_file" "$download_url"; then
            continue
        fi
        actual_size=$(wc -c < "$temporary_file")
        if [[ "$actual_size" -eq "$expected_size" ]]; then
            downloaded=true
            break
        fi
    done
    [[ "$downloaded" == true ]] || {
        echo "No configured source returned bytes ${offset}-${end} correctly." >&2
        exit 1
    }
    cat "$temporary_file" >> "$output_file"
    offset=$((end + 1))
done
rm -f "$temporary_file"

actual_size=$(wc -c < "$output_file")
[[ "$actual_size" -eq "$content_length" ]] || {
    echo "Downloaded ${actual_size} bytes, expected ${content_length}." >&2
    exit 1
}
