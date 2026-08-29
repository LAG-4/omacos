#!/bin/zsh

set -euo pipefail

omacos_home=${OMACOS_TEST_HOME:-$HOME}
applications_directory="$omacos_home/Applications/OMacOS Web Apps"
action=${1:-}

validate_name() {
  local name=$1
  if [[ -z $name || $name == *[^A-Za-z0-9\ _-]* ]]; then
    print -u2 "Web app names may contain letters, numbers, spaces, underscores, and hyphens."
    return 1
  fi
}

validate_url() {
  local url=$1
  if [[ $url != https://* && $url != http://* ]]; then
    print -u2 "Web app URL must begin with https:// or http://"
    return 1
  fi
}

case $action in
  install)
    name=${2:-}
    url=${3:-}
    validate_name "$name"
    validate_url "$url"

    app_directory="$applications_directory/$name.app"
    contents_directory="$app_directory/Contents"
    executable_directory="$contents_directory/MacOS"
    mkdir -p "$executable_directory"

    escaped_url=$(printf %q "$url")
    bundle_slug=${name// /-}
    bundle_slug=${bundle_slug//_/-}
    bundle_slug=${(L)bundle_slug}
    cat > "$executable_directory/launcher" <<EOF
#!/bin/zsh
exec "\${HOME}/.local/bin/omacos" launch webapp $escaped_url
EOF
    chmod +x "$executable_directory/launcher"

    plutil -create xml1 "$contents_directory/Info.plist"
    plutil -insert CFBundleDevelopmentRegion -string en "$contents_directory/Info.plist"
    plutil -insert CFBundleDisplayName -string "$name" "$contents_directory/Info.plist"
    plutil -insert CFBundleExecutable -string launcher "$contents_directory/Info.plist"
    plutil -insert CFBundleIdentifier -string "dev.omacos.webapp.$bundle_slug" "$contents_directory/Info.plist"
    plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$contents_directory/Info.plist"
    plutil -insert CFBundleName -string "$name" "$contents_directory/Info.plist"
    plutil -insert CFBundlePackageType -string APPL "$contents_directory/Info.plist"
    plutil -insert CFBundleVersion -string 1 "$contents_directory/Info.plist"
    print "Installed web app: $app_directory"
    ;;
  list)
    if [[ ! -d $applications_directory ]]; then
      exit 0
    fi
    for app_directory in "$applications_directory"/*.app(N); do
      print "${app_directory:t:r}"
    done
    ;;
  remove)
    name=${2:-}
    validate_name "$name"
    app_directory="$applications_directory/$name.app"
    if [[ ! -d $app_directory ]]; then
      print -u2 "OMacOS web app not found: $name"
      exit 1
    fi
    rm -rf "$app_directory"
    print "Removed web app: $name"
    ;;
  *)
    print -u2 "Usage: omacos webapp <install NAME URL|list|remove NAME>"
    exit 1
    ;;
esac
