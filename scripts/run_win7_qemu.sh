#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
    echo "usage: $0 INSTALL_ISO BOOTSTRAP_ISO UNATTEND_IMAGE RESULTS_IMAGE WORK_DIRECTORY TIMEOUT_SECONDS" >&2
    exit 64
fi

install_iso=$1
bootstrap_iso=$2
unattend_image=$3
results_image=$4
work_directory=$5
timeout_seconds=$6

for required_file in "$install_iso" "$bootstrap_iso" "$unattend_image" "$results_image"; do
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
monitor_socket="$work_directory/qemu-monitor.sock"
screenshot="$work_directory/qemu-screen.ppm"
rm -f "$system_disk" "$serial_log" "$monitor_socket" "$screenshot"
qemu-img create -f qcow2 "$system_disk" 24G >/dev/null

capture_screen() {
    [[ -S "$monitor_socket" ]] || return 0
    printf 'screendump %s\n' "$screenshot" | timeout 5 nc -U "$monitor_socket" >/dev/null 2>&1 || true
}

qemu-system-x86_64 \
    -accel kvm \
    -cpu host \
    -machine pc \
    -m 3072 \
    -smp 2 \
    -rtc base=localtime \
    -nic none \
    -boot once=d,order=c \
    -drive "file=$system_disk,if=ide,media=disk,format=qcow2" \
    -drive "file=$install_iso,if=ide,media=cdrom,readonly=on" \
    -drive "file=$bootstrap_iso,if=ide,media=cdrom,readonly=on" \
    -drive "file=$unattend_image,if=floppy,format=raw,readonly=on" \
    -drive "file=$results_image,if=ide,media=disk,format=raw" \
    -vga std \
    -display none \
    -monitor "unix:$monitor_socket,server,nowait" \
    -serial "file:$serial_log" &
qemu_pid=$!
deadline=$((SECONDS + timeout_seconds))
qemu_status=0

while kill -0 "$qemu_pid" 2>/dev/null; do
    if [[ "$SECONDS" -ge "$deadline" ]]; then
        capture_screen
        kill -TERM "$qemu_pid"
        sleep 5
        if kill -0 "$qemu_pid" 2>/dev/null; then
            kill -KILL "$qemu_pid"
        fi
        qemu_status=124
        break
    fi
    sleep 5
done

if [[ "$qemu_status" -eq 0 ]]; then
    set +e
    wait "$qemu_pid"
    qemu_status=$?
    set -e
else
    set +e
    wait "$qemu_pid"
    set -e
fi

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
