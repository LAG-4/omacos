#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-update-channel-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT
fake_curl="$temporary_home/curl"
mkdir -p "$temporary_home/.config/omacos"

cat > "$fake_curl" <<'EOF'
#!/bin/zsh
output_path=""
for (( index = 1; index <= $#; index += 1 )); do
  if [[ ${@[index]} == "-o" ]]; then
    output_path=${@[index + 1]}
  fi
done
[[ -n $output_path ]] || exit 1
print '[{"tag_name":"v0.3.0-rc.2","prerelease":true,"draft":false},{"tag_name":"v0.2.0","prerelease":false,"draft":false}]' > "$output_path"
EOF
chmod +x "$fake_curl"

print rc > "$temporary_home/.config/omacos/update-channel"
rc_output=$(
  OMACOS_TEST_HOME="$temporary_home" \
  OMACOS_ROOT="$project_root" \
  OMACOS_CURL="$fake_curl" \
  "$project_root/scripts/update.zsh" check
)
[[ $rc_output == 'Available OMacOS version: 0.3.0-rc.2 (rc)' ]]

print dev > "$temporary_home/.config/omacos/update-channel"
dev_output=$(OMACOS_TEST_HOME="$temporary_home" OMACOS_ROOT="$project_root" "$project_root/scripts/update.zsh" check)
[[ $dev_output == *'public dev branch'* ]]

print "RC and dev update channel test passed"
