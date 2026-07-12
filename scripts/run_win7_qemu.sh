#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
    echo "usage: $0 INSTALL_ISO BOOTSTRAP_ISO RESULTS_IMAGE WORK_DIRECTORY TIMEOUT_SECONDS" >&2
    exit 64
fi

install_iso=$1
bootstrap_iso=$2
results_image=$3
work_directory=$4
timeout_seconds=$5

for required_file in "$install_iso" "$bootstrap_iso" "$results_image"; do
    [[ -f "$required_file" ]] || {
        echo "required image does not exist: $required_file" >&2
        exit 66
    }
done
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || {
    echo "timeout must be a positive integer" >&2
    exit 64
}
[[ -r /dev/kvm && -w /dev/kvm ]] || {
    echo "/dev/kvm is not available to this process" >&2
    exit 69
}

mkdir -p "$work_directory"
system_disk="$work_directory/win7-system.qcow2"
serial_log="$work_directory/serial.log"
rm -f "$system_disk" "$serial_log"
qemu-img create -f qcow2 "$system_disk" 24G >/dev/null

set +e
timeout --foreground "$timeout_seconds" qemu-system-x86_64 \
    -accel kvm \
    -cpu host \
    -machine pc \
    -m 3072 \
    -smp 2 \
    -rtc base=localtime \
    -boot once=d,order=c \
    -drive "file=$system_disk,if=ide,media=disk,format=qcow2" \
    -drive "file=$install_iso,if=ide,media=cdrom,readonly=on" \
    -drive "file=$bootstrap_iso,if=ide,media=cdrom,readonly=on" \
    -drive "file=$results_image,if=ide,media=disk,format=raw" \
    -vga std \
    -display none \
    -monitor none \
    -serial "file:$serial_log"
qemu_status=$?
set -e

if [[ $qemu_status -eq 124 ]]; then
    echo "Windows guest did not shut down within ${timeout_seconds} seconds." >&2
    tail -n 200 "$serial_log" >&2 || true
    exit 124
fi
if [[ $qemu_status -ne 0 ]]; then
    echo "QEMU exited with status $qemu_status." >&2
    tail -n 200 "$serial_log" >&2 || true
    exit "$qemu_status"
fi
