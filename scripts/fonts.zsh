#!/bin/zsh

set -euo pipefail

brew_command=${OMACOS_BREW:-$(command -v brew || true)}

font_package() {
  case $1 in
    cascadia) print "font-cascadia-code-nf" ;;
    meslo) print "font-meslo-lg-nerd-font" ;;
    fira) print "font-fira-code-nerd-font" ;;
    victor) print "font-victor-mono-nerd-font" ;;
    bitstream) print "font-bitstream-vera-sans-mono-nerd-font" ;;
    iosevka) print "font-iosevka-term-nerd-font" ;;
    *) print -u2 "Unknown OMacOS font: $1"; return 1 ;;
  esac
}

case ${1:-list} in
  list)
    for font in cascadia meslo fira victor bitstream iosevka; do
      package=$(font_package "$font")
      if [[ -n $brew_command ]] && "$brew_command" list --cask "$package" >/dev/null 2>&1; then
        status=installed
      else
        status=available
      fi
      print "$font\t$package\t$status"
    done
    ;;
  install|remove)
    action=$1
    package=$(font_package "${2:-}")
    [[ -n $brew_command ]] || { print -u2 "Homebrew is required for font management."; exit 1; }
    if [[ $action == "install" ]]; then
      "$brew_command" install --cask "$package"
    else
      "$brew_command" uninstall --cask "$package"
    fi
    ;;
  *) print -u2 "Usage: omacos font <list|install NAME|remove NAME>"; exit 1 ;;
esac
