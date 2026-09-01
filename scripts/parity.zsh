#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${OMACOS_ROOT:-${script_directory:h}}
ledger=${OMACOS_PARITY_LEDGER:-$project_root/docs/quattro-parity.json}

[[ -f $ledger ]] || { print -u2 "OMacOS parity ledger is missing: $ledger"; exit 1; }

case ${1:-summary} in
  summary)
    jq -r '
      "Quattro parity at \(.reference.commit)",
      "total=\(.summary.total)",
      "implemented=\(.summary.implemented)",
      "limited=\(.summary.limited)",
      "pending=\(.summary.pending)",
      "unavailable=\(.summary.unavailable)",
      "not-applicable=\(.summary.notApplicable)",
      "automated-route=\(.summary.automatedRoute)",
      "visual-fixture=\(.summary.visualFixture)",
      "hardware-required=\(.summary.hardwareRequired)",
      "route-only=\(.summary.routeOnly)"
    ' "$ledger"
    ;;
  list)
    status=${2:-all}
    kind=${3:-all}
    jq -r --arg status "$status" --arg kind "$kind" '
      [.items[][]
        | select($status == "all" or .implementationStatus == $status)
        | select($kind == "all" or .kind == $kind)]
      | sort_by(.kind, .id)[]
      | [.implementationStatus, .grade, .kind, .id, .title, .route] | @tsv
    ' "$ledger"
    ;;
  show)
    kind=${2:-}
    id=${3:-}
    [[ -n $kind && -n $id ]] || { print -u2 'Usage: omacos parity show KIND ID'; exit 1; }
    jq -e --arg kind "$kind" --arg id "$id" '.items[][] | select(.kind == $kind and .id == $id)' "$ledger"
    ;;
  *)
    print -u2 'Usage: omacos parity <summary|list [STATUS [KIND]]|show KIND ID>'
    exit 1
    ;;
esac
