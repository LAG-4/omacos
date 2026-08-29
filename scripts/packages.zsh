#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
installed_root=${OMACOS_ROOT:-${script_directory:h}}
catalog=${OMACOS_PACKAGE_CATALOG:-$installed_root/config/optional-packages.json}
brew_command=${OMACOS_BREW:-$(command -v brew || true)}
test_mode=${OMACOS_TEST_MODE:-false}

package_record() {
  local package_id=$1
  jq -ce --arg id "$package_id" '.packages[] | select(.id == $id)' "$catalog" \
    || { print -u2 "Unknown optional package: $package_id"; return 1; }
}

confirm_package_action() {
  local prompt=$1
  local assume_yes=$2
  $assume_yes && return 0
  print -n "$prompt [y/N] "
  [[ -r /dev/tty ]] && read -r answer </dev/tty && [[ $answer == [yY] || $answer == [yY][eE][sS] ]]
}

case ${1:-list} in
  list)
    category=${2:-}
    if [[ $category == "--json" ]]; then
      jq -c '.packages' "$catalog"
    elif [[ -n $category ]]; then
      jq -r --arg category "$category" '.packages[] | select(.category == $category) | [.id,.name,.description] | @tsv' "$catalog"
    else
      jq -r '.packages[] | [.category,.id,.name,.description] | @tsv' "$catalog"
    fi
    ;;
  categories)
    jq -r '[.packages[].category] | unique[]' "$catalog"
    ;;
  status)
    record=$(package_record "${2:-}")
    package=$(jq -r '.package' <<< "$record")
    if [[ -n $brew_command ]] && "$brew_command" list --cask "$package" >/dev/null 2>&1; then
      print 'installed'
    else
      print 'not-installed'
    fi
    ;;
  install|remove)
    action=$1
    package_id=${2:-}
    assume_yes=false
    [[ ${3:-} == "--yes" || ${3:-} == "-y" ]] && assume_yes=true
    record=$(package_record "$package_id")
    package=$(jq -r '.package' <<< "$record")
    name=$(jq -r '.name' <<< "$record")
    [[ -n $brew_command ]] || { print -u2 'Homebrew is required for optional packages.'; exit 1; }
    confirm_package_action "$action $name through Homebrew?" "$assume_yes" || { print 'Cancelled.'; exit 0; }
    if [[ $action == "install" ]]; then
      "$brew_command" install --cask "$package"
    else
      "$brew_command" uninstall --cask "$package"
    fi
    ;;
  *) print -u2 'Usage: omacos package <list [CATEGORY|--json]|categories|status ID|install ID [--yes]|remove ID [--yes]>'; exit 1 ;;
esac
