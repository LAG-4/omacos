#!/bin/zsh

set -euo pipefail

repo_root=${0:A:h:h}
test_home=$(mktemp -d)
collector_directory=$(mktemp -d)
trap 'rm -rf "$test_home" "$collector_directory"' EXIT

for collector in claude codex fireworks; do
  /usr/bin/python3 -c 'compile(open(__import__("sys").argv[1]).read(), __import__("sys").argv[1], "exec")' "$repo_root/bin/omacos-agent-usage-$collector"
done

cp "$repo_root/test/fixtures/omacos-agent-usage-demo" "$collector_directory/omacos-agent-usage-demo"
chmod +x "$collector_directory/omacos-agent-usage-demo"

OMACOS_TEST_HOME="$test_home" \
  OMACOS_AGENT_COLLECTOR_DIRECTORY="$collector_directory" \
  "$repo_root/bin/omacos-agent-usage-update" demo

record="$test_home/.local/state/omacos/agents/usage/demo.json"
[[ -f $record ]]
jq -e '.id == "demo" and .todayTotalTokens == 4000 and .limits[0].percent == 0.42' "$record" >/dev/null

print 'agent usage collector tests passed'
