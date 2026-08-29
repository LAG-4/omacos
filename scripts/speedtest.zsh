#!/bin/zsh

set -euo pipefail

network_quality_command=${OMACOS_NETWORK_QUALITY:-/usr/bin/networkQuality}
dd_command=${OMACOS_DD:-/bin/dd}
speed_test_file=''

network_speedtest() {
  local output
  output=$($network_quality_command -c)
  jq -c '{
    schemaVersion: 1,
    downloadMbps: ((.dl_throughput // 0) / 1000000),
    uploadMbps: ((.ul_throughput // 0) / 1000000),
    responsivenessRPM: (.responsiveness // 0),
    idleLatencyMs: (.base_rtt // 0)
  }' <<< "$output"
}

disk_speedtest() {
  local target_directory=${1:-${TMPDIR:-/tmp}}
  local write_output
  local read_output
  local write_bytes_per_second
  local read_bytes_per_second
  [[ -d $target_directory && -w $target_directory ]] || { print -u2 "Disk test target is not writable: $target_directory"; return 1; }
  speed_test_file=$(mktemp "$target_directory/omacos-disk-speed.XXXXXX")
  trap 'rm -f "$speed_test_file"' EXIT
  write_output=$($dd_command if=/dev/zero of="$speed_test_file" bs=4m count="${OMACOS_DISK_TEST_COUNT:-16}" conv=fsync 2>&1)
  read_output=$($dd_command if="$speed_test_file" of=/dev/null bs=4m 2>&1)
  write_bytes_per_second=$(sed -nE 's/.*\(([0-9]+) bytes\/sec\).*/\1/p' <<< "$write_output" | tail -1)
  read_bytes_per_second=$(sed -nE 's/.*\(([0-9]+) bytes\/sec\).*/\1/p' <<< "$read_output" | tail -1)
  [[ -n $write_bytes_per_second && -n $read_bytes_per_second ]] || { print -u2 'Could not parse disk speed output.'; return 1; }
  jq -nc \
    --argjson write "$write_bytes_per_second" \
    --argjson read "$read_bytes_per_second" \
    '{schemaVersion:1,writeMBps:($write / 1000000),readMBps:($read / 1000000)}'
}

case ${1:-} in
  network) network_speedtest ;;
  disk) disk_speedtest "${2:-}" ;;
  *) print -u2 'Usage: omacos speedtest <network|disk [DIRECTORY]>'; exit 1 ;;
esac
