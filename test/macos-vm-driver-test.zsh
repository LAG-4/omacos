#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_directory=$(mktemp -d -t omacos-vm-driver-test.XXXXXX)
trap 'rm -rf "$temporary_directory"' EXIT
fake_tart="$temporary_directory/tart"
tart_log="$temporary_directory/tart.log"

cat > "$fake_tart" <<'EOF'
#!/bin/zsh
print -r -- "$*" >> "$OMACOS_VM_TART_LOG"
if [[ $1 == list ]]; then
  print 'Name State'
  print 'omacos-macos27-base stopped'
  print 'omacos-macos27-test stopped'
fi
EOF
chmod +x "$fake_tart"

export OMACOS_ROOT="$project_root"
export OMACOS_TART="$fake_tart"
export OMACOS_VM_TART_LOG="$tart_log"
export OMACOS_VM_AVAILABLE_GIB=100
export OMACOS_VM_MINIMUM_FREE_GIB=70

driver="$project_root/scripts/macos-vm-test.zsh"
plan_output=$("$driver" plan)
grep -Fq 'baseline -> install -> doctor -> uninstall -> compare' <<< "$plan_output"
doctor_output=$("$driver" doctor)
grep -Fq '[ok] 100 GiB free for VM storage' <<< "$doctor_output"
clean_output=$("$driver" clean --yes)
grep -Fq 'The reusable base VM was kept' <<< "$clean_output"
grep -Fq 'stop omacos-macos27-test' "$tart_log"
grep -Fq 'delete omacos-macos27-test' "$tart_log"
if OMACOS_VM_NAME=personal-work-vm "$driver" clean --yes >/dev/null 2>&1; then
  print -u2 "VM driver accepted a VM outside its test namespace"
  exit 1
fi

print "Disposable macOS VM driver test passed"
