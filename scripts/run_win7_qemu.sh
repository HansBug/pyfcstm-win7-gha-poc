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
(( timeout_seconds <= 21600 )) || {
    echo "timeout must not exceed the GitHub-hosted job limit of 21600 seconds" >&2
    exit 64
}
mkdir -p "$work_directory"
system_disk="$work_directory/win7-system.qcow2"
serial_log="$work_directory/serial.log"
qemu_stderr_log="$work_directory/qemu.stderr.log"
monitor_socket="$work_directory/qemu-monitor.sock"
screenshot="$work_directory/qemu-screen.ppm"
screen_directory="$work_directory/qemu-screens"
exit_status_file="$work_directory/qemu-exit-status.txt"
acceleration_file="$work_directory/qemu-acceleration.txt"
rm -f "$system_disk" "$serial_log" "$qemu_stderr_log" "$monitor_socket" "$screenshot" "$exit_status_file" "$acceleration_file"
rm -rf "$screen_directory"
mkdir -p "$screen_directory"
qemu-img create -f qcow2 "$system_disk" 24G >/dev/null

capture_screen_to() {
    local target=$1
    [[ -S "$monitor_socket" ]] || return 0
    local temporary="${target}.tmp"
    rm -f "$temporary"
    printf 'screendump %s\n' "$temporary" | timeout 5 nc -U "$monitor_socket" >/dev/null 2>&1 || true
    if [[ -s "$temporary" ]]; then
        mv -f "$temporary" "$target"
    else
        rm -f "$temporary"
    fi
}

capture_screen() {
    capture_screen_to "$screenshot"
}

capture_screen_periodically() {
    local frame=0
    while kill -0 "$qemu_pid" 2>/dev/null; do
        frame=$((frame + 1))
        capture_screen_to "$screen_directory/frame-$(printf '%03d' "$frame").ppm"
        if (( frame > 8 )); then
            rm -f "$screen_directory/frame-$(printf '%03d' "$((frame - 8))").ppm"
        fi
        sleep 10
    done
}

qemu_common_args=(
    -machine pc \
    -m 3072 \
    -smp 2 \
    -rtc base=localtime \
    -nic none \
    -boot once=d,order=c \
    -drive "file=$system_disk,if=ide,index=0,media=disk,format=qcow2" \
    -drive "file=$results_image,if=ide,index=1,media=disk,format=raw" \
    -drive "file=$install_iso,if=ide,index=2,media=cdrom,readonly=on" \
    -drive "file=$bootstrap_iso,if=ide,index=3,media=cdrom,readonly=on" \
    -drive "file=$unattend_image,if=floppy,format=raw,readonly=on" \
    -vga std \
    -display none \
    -monitor "unix:$monitor_socket,server,nowait" \
    -serial "file:$serial_log"
)

launch_qemu() {
    local mode=$1
    local acceleration_args=()
    if [[ "$mode" == kvm ]]; then
        acceleration_args=(-accel kvm -cpu host)
    else
        acceleration_args=(-accel tcg,thread=multi -cpu max)
    fi
    qemu-system-x86_64 "${acceleration_args[@]}" "${qemu_common_args[@]}" \
        2>>"$qemu_stderr_log" &
    qemu_pid=$!
    sleep 5
    if kill -0 "$qemu_pid" 2>/dev/null; then
        printf 'mode=%s\n' "$mode" > "$acceleration_file"
        return 0
    fi
    set +e
    wait "$qemu_pid"
    local launch_status=$?
    set -e
    echo "QEMU $mode launch exited with status $launch_status." >&2
    return 1
}

if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    if ! launch_qemu kvm; then
        echo "KVM launch failed; retrying with QEMU TCG." >&2
        rm -f "$monitor_socket"
        launch_qemu tcg
    fi
else
    echo "KVM is unavailable; using QEMU TCG." >&2
    launch_qemu tcg
fi
capture_screen_periodically &
capture_pid=$!
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

kill "$capture_pid" 2>/dev/null || true
wait "$capture_pid" 2>/dev/null || true

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

printf '%s\n' "$qemu_status" > "$exit_status_file"

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
