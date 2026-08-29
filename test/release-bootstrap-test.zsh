#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-release-bootstrap-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT
fixture_directory="$temporary_directory/fixtures"
test_home="$temporary_directory/home"
mkdir -p "$fixture_directory" "$test_home"

if [[ ! -x $project_root/.build/release/omacos-shell ]]; then
  swift build --package-path "$project_root" -c release >/dev/null
fi
OMACOS_SKIP_BUILD=true OMACOS_CODESIGN_IDENTITY=- \
  "$project_root/scripts/package-release.zsh" "$fixture_directory/release" >/dev/null
release_archive=$(find "$fixture_directory/release" -maxdepth 1 -name 'OMacOS-*-arm64.zip' -print -quit)
cp "$release_archive" "$fixture_directory/OMacOS-0.2.0-dev-arm64.zip"
cp "$release_archive.sha256" "$fixture_directory/OMacOS-0.2.0-dev-arm64.zip.sha256"
sed -i '' "s/${release_archive:t}/OMacOS-0.2.0-dev-arm64.zip/" "$fixture_directory/OMacOS-0.2.0-dev-arm64.zip.sha256"

mkdir -p "$temporary_directory/source/omacos-0.2.0-dev"
rsync -a --exclude .git --exclude .build "$project_root/" "$temporary_directory/source/omacos-0.2.0-dev/"
tar -czf "$fixture_directory/source.tar.gz" -C "$temporary_directory/source" omacos-0.2.0-dev
mv "$temporary_directory/source/omacos-0.2.0-dev" "$temporary_directory/source/omacos-main"
tar -czf "$fixture_directory/main.tar.gz" -C "$temporary_directory/source" omacos-main

print -r -- '{"tag_name":"v0.2.0-dev"}' > "$fixture_directory/release.json"

cat > "$fixture_directory/curl" <<'EOF'
#!/bin/zsh
set -euo pipefail
output_path=''
url=''
while (( $# > 0 )); do
  case $1 in
    -o) output_path=$2; shift 2 ;;
    -*) shift ;;
    *) url=$1; shift ;;
  esac
done
case $url in
  *releases/latest)
    if [[ ${OMACOS_RELEASE_UNAVAILABLE:-false} == "true" ]]; then
      exit 22
    fi
    source_path="$OMACOS_RELEASE_FIXTURES/release.json"
    ;;
  *OMacOS-0.2.0-dev-arm64.zip.sha256) source_path="$OMACOS_RELEASE_FIXTURES/OMacOS-0.2.0-dev-arm64.zip.sha256" ;;
  *OMacOS-0.2.0-dev-arm64.zip) source_path="$OMACOS_RELEASE_FIXTURES/OMacOS-0.2.0-dev-arm64.zip" ;;
  *refs/tags/v0.2.0-dev.tar.gz) source_path="$OMACOS_RELEASE_FIXTURES/source.tar.gz" ;;
  *refs/heads/main.tar.gz) source_path="$OMACOS_RELEASE_FIXTURES/main.tar.gz" ;;
  *) print -u2 "Unexpected fixture URL: $url"; exit 1 ;;
esac
if [[ -n $output_path ]]; then
  cp "$source_path" "$output_path"
else
  /bin/cat "$source_path"
fi
EOF
chmod +x "$fixture_directory/curl"

dry_run_home="$temporary_directory/dry-run-home"
mkdir -p "$dry_run_home"
dry_run_output=$(
  cd "$temporary_directory"
  OMACOS_CURL="$fixture_directory/curl" \
    OMACOS_RELEASE_FIXTURES="$fixture_directory" \
    OMACOS_INSTALL_CHANNEL=release \
    OMACOS_TEST_MODE=true \
    OMACOS_TEST_HOME="$dry_run_home" \
    /bin/zsh -s -- --dry-run < "$project_root/install.sh"
)
[[ $dry_run_output == *'Downloading signed OMacOS release v0.2.0-dev'* ]]
[[ $dry_run_output == *'Dry run complete. No files or packages were changed.'* ]]
[[ ! -e $dry_run_home/.local/share/omacos/OMacOSShell.app ]]

fallback_output=$(
  cd "$temporary_directory"
  OMACOS_CURL="$fixture_directory/curl" \
    OMACOS_RELEASE_FIXTURES="$fixture_directory" \
    OMACOS_RELEASE_UNAVAILABLE=true \
    OMACOS_INSTALL_CHANNEL=auto \
    OMACOS_TEST_MODE=true \
    OMACOS_TEST_HOME="$dry_run_home" \
    /bin/zsh -s -- --dry-run < "$project_root/install.sh"
)
[[ $fallback_output == *'Downloading the current OMacOS installer source...'* ]]
[[ $fallback_output == *'Dry run complete. No files or packages were changed.'* ]]

bootstrap_output=$(
  cd "$temporary_directory"
  OMACOS_CURL="$fixture_directory/curl" \
    OMACOS_RELEASE_FIXTURES="$fixture_directory" \
    OMACOS_INSTALL_CHANNEL=release \
    OMACOS_TEST_MODE=true \
    OMACOS_TEST_HOME="$test_home" \
    /bin/zsh -s -- --yes < "$project_root/install.sh"
)

[[ $bootstrap_output == *'Downloading signed OMacOS release v0.2.0-dev'* ]]
[[ $bootstrap_output == *'Installing the signed native OMacOS shell'* ]]
installed_app="$test_home/.local/share/omacos/OMacOSShell.app"
codesign --verify --deep --strict "$installed_app"
[[ $(plutil -extract CFBundleIdentifier raw "$installed_app/Contents/Info.plist") == 'dev.omacos.shell' ]]

OMACOS_TEST_HOME="$test_home" OMACOS_ROOT="$test_home/.local/share/omacos/current" \
  "$test_home/.local/bin/omacos" uninstall --yes >/dev/null

print 'Signed release bootstrap and uninstall test passed'
