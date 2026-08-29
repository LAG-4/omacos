#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${OMACOS_ROOT:-${script_directory:h}}
omacos_home=${OMACOS_TEST_HOME:-$HOME}
osascript_command=${OMACOS_OSASCRIPT:-/usr/bin/osascript}
mise_command=${OMACOS_MISE:-mise}
utility=${1:-}
shift || true

case $utility in
  ascii)
    /usr/bin/banner "${*:-OMacOS}"
    ;;
  branch)
    case ${1:-status} in
      status|current) git -C "$project_root" branch --show-current 2>/dev/null || print main ;;
      list) git -C "$project_root" branch --format='%(refname:short)' 2>/dev/null || print main ;;
      *) print -u2 'Usage: omacos branch <status|list>'; exit 1 ;;
    esac
    ;;
  channel)
    case ${1:-status} in
      status|list) print 'main (single tested open-source channel)' ;;
      *) print -u2 'OMacOS currently supports only the main channel.'; exit 2 ;;
    esac
    ;;
  file)
    case ${1:-choose} in
      choose|choose-file)
        "$osascript_command" -e 'POSIX path of (choose file with prompt "Choose a file for OMacOS")'
        ;;
      choose-folder)
        "$osascript_command" -e 'POSIX path of (choose folder with prompt "Choose a folder for OMacOS")'
        ;;
      *) print -u2 'Usage: omacos file <choose|choose-folder>'; exit 1 ;;
    esac
    ;;
  hook)
    hook_directory="$omacos_home/.config/omacos/hooks"
    case ${1:-list} in
      list)
        [[ -d $hook_directory ]] && find "$hook_directory" -maxdepth 1 -type f -perm -u+x -print | sort || true
        ;;
      run)
        hook_name=${2:-}
        if [[ -z $hook_name || $hook_name == *[/\\]* || $hook_name == .* ]]; then
          print -u2 'Hook names must be simple filenames.'
          exit 1
        fi
        hook_path="$hook_directory/$hook_name"
        [[ -x $hook_path ]] || { print -u2 "OMacOS hook is not executable: $hook_path"; exit 1; }
        OMACOS_ROOT="$project_root" OMACOS_TEST_HOME="$omacos_home" "$hook_path" "${@:3}"
        ;;
      *) print -u2 'Usage: omacos hook <list|run NAME [ARGS...]>'; exit 1 ;;
    esac
    ;;
  installed)
    "$project_root/scripts/packages.zsh" status "${1:-}"
    ;;
  mise)
    command -v "$mise_command" >/dev/null 2>&1 || { print -u2 'mise is not installed.'; exit 1; }
    "$mise_command" "$@"
    ;;
  restart)
    case ${1:-shell} in
      shell) "$project_root/bin/omacos" shell restart ;;
      *) print -u2 'Usage: omacos restart shell'; exit 1 ;;
    esac
    ;;
  screensaver)
    "$project_root/scripts/toggles.zsh" screensaver
    ;;
  version)
    version=$(<"$project_root/VERSION")
    commit=$(git -C "$project_root" rev-parse --short HEAD 2>/dev/null || print installed)
    print "OMacOS $version ($commit)"
    ;;
  *)
    print -u2 'Unknown OMacOS utility group.'
    exit 1
    ;;
esac
