#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
temporary_directory=$(mktemp -d -t omacos-speedtest.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT

network=$(OMACOS_NETWORK_QUALITY="$project_root/test/fixtures/fake-network-quality.zsh" \
  "$project_root/scripts/speedtest.zsh" network)
jq -e '.downloadMbps == 245 and .uploadMbps == 42 and .responsivenessRPM == 318' <<< "$network" >/dev/null

disk=$(OMACOS_DD="$project_root/test/fixtures/fake-dd.zsh" \
  "$project_root/scripts/speedtest.zsh" disk "$temporary_directory")
jq -e '.writeMBps == 250 and .readMBps == 500' <<< "$disk" >/dev/null

print 'Network and disk speed test adapter tests passed'
