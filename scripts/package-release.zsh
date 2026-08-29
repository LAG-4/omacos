#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
output_directory=${1:-$project_root/dist}
configuration=${OMACOS_BUILD_CONFIGURATION:-release}
codesign_identity=${OMACOS_CODESIGN_IDENTITY:--}
skip_build=${OMACOS_SKIP_BUILD:-false}
version=$(<"$project_root/VERSION")
short_version=${version%%-*}
artifact_name="OMacOS-$version-arm64"
app_path="$output_directory/OMacOSShell.app"
archive_path="$output_directory/$artifact_name.zip"
metadata_path="$output_directory/$artifact_name.json"
checksum_path="$archive_path.sha256"

if ! $skip_build; then
  swift build --package-path "$project_root" -c "$configuration"
fi

build_directory="$project_root/.build/$configuration"
shell_binary="$build_directory/omacos-shell"
[[ -x $shell_binary ]] || { print -u2 "Release shell binary is missing: $shell_binary"; exit 1; }

mkdir -p "$output_directory"
rm -rf "$app_path"
rm -f "$archive_path" "$metadata_path" "$checksum_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$shell_binary" "$app_path/Contents/MacOS/omacos-shell"
cp "$project_root/app/Info.plist" "$app_path/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$short_version" "$app_path/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(date -u +%Y%m%d%H%M)" "$app_path/Contents/Info.plist"

resource_bundles=("$build_directory"/*.bundle(N) "$build_directory"/*.resources(N))
(( ${#resource_bundles[@]} > 0 )) || { print -u2 'Swift resource bundle is missing from the release build.'; exit 1; }
cp -R "$resource_bundles[1]" "$app_path/Contents/Resources/"

codesign_arguments=(--force --deep --options runtime --entitlements "$project_root/app/OMacOSShell.entitlements" --sign "$codesign_identity")
if [[ $codesign_identity == "-" ]]; then
  codesign_arguments+=(--timestamp=none)
else
  codesign_arguments+=(--timestamp)
fi
codesign "${codesign_arguments[@]}" "$app_path"
codesign --verify --deep --strict "$app_path"

package_archive() {
  rm -f "$archive_path"
  ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive_path"
}

package_archive

if [[ -n ${OMACOS_NOTARY_KEY_PATH:-} && -n ${OMACOS_NOTARY_KEY_ID:-} && -n ${OMACOS_NOTARY_ISSUER_ID:-} ]]; then
  xcrun notarytool submit "$archive_path" \
    --key "$OMACOS_NOTARY_KEY_PATH" \
    --key-id "$OMACOS_NOTARY_KEY_ID" \
    --issuer "$OMACOS_NOTARY_ISSUER_ID" \
    --wait
  xcrun stapler staple "$app_path"
  package_archive
fi

archive_checksum=$(shasum -a 256 "$archive_path" | awk '{print $1}')
print "$archive_checksum  ${archive_path:t}" > "$checksum_path"
jq -n \
  --arg version "$version" \
  --arg architecture arm64 \
  --arg archive "${archive_path:t}" \
  --arg sha256 "$archive_checksum" \
  --arg identity "$codesign_identity" \
  '{schemaVersion:1, version:$version, architecture:$architecture, archive:$archive, sha256:$sha256, codesignIdentity:$identity}' \
  > "$metadata_path"

print "Packaged $archive_path"
