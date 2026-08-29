#!/bin/zsh

set -euo pipefail

project_root=${0:A:h:h}
temporary_home=$(mktemp -d -t omacos-services.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

tailscale=$(OMACOS_TEST_HOME="$temporary_home" OMACOS_TAILSCALE="$project_root/test/fixtures/fake-tailscale.zsh" \
  "$project_root/scripts/services.zsh" tailscale status)
jq -e '.installed and .online and .tailnet == "example.net" and .machines[0].name == "studio"' <<< "$tailscale" >/dev/null

dropbox=$(OMACOS_TEST_HOME="$temporary_home" OMACOS_PGREP=/usr/bin/false \
  "$project_root/scripts/services.zsh" dropbox status)
jq -e '.installed == false and .running == false' <<< "$dropbox" >/dev/null

print 'Tailscale and Dropbox service adapter tests passed'
