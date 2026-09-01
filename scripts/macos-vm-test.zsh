#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${OMACOS_ROOT:-${script_directory:h}}
tart_command=${OMACOS_TART:-tart}
base_vm=${OMACOS_VM_BASE:-omacos-macos27-base}
test_vm=${OMACOS_VM_NAME:-omacos-macos27-test}
vm_user=${OMACOS_VM_USER:-omacos}
vm_password=${OMACOS_VM_PASSWORD:-omacos-test-only}
artifact_directory=${OMACOS_VM_ARTIFACTS:-$project_root/.artifacts/macos-vm}
minimum_free_gib=${OMACOS_VM_MINIMUM_FREE_GIB:-70}
assume_yes=false

validate_vm_name() {
  local vm_name=$1
  if [[ $vm_name != omacos-macos27-* ]]; then
    print -u2 "Refusing to manage a VM outside the OMacOS test namespace: $vm_name"
    return 1
  fi
}

command_is_available() {
  if [[ $1 == */* ]]; then
    [[ -x $1 ]]
  else
    command -v "$1" >/dev/null 2>&1
  fi
}

available_storage_gib() {
  if [[ -n ${OMACOS_VM_AVAILABLE_GIB:-} ]]; then
    print -r -- "$OMACOS_VM_AVAILABLE_GIB"
    return
  fi
  local storage_path=${TART_HOME:-$HOME}
  [[ -e $storage_path ]] || storage_path=${storage_path:h}
  df -Pk "$storage_path" | awk 'NR == 2 { printf "%d\n", $4 / 1024 / 1024 }'
}

vm_exists() {
  local vm_name=$1
  "$tart_command" list 2>/dev/null | awk 'NR > 1 { print $1 }' | grep -qxF "$vm_name"
}

print_plan() {
  local free_gib
  free_gib=$(available_storage_gib)
  print "OMacOS macOS 27 VM test plan"
  print "  Base VM:       $base_vm"
  print "  Disposable VM: $test_vm"
  print "  Runtime:       Tart on Apple Virtualization.framework"
  print "  Storage:       ${TART_HOME:-$HOME} ($free_gib GiB free)"
  print "  Source:        current checkout, including uncommitted changes"
  print "  Lifecycle:     baseline -> install -> doctor -> uninstall -> compare"
  print "  Preserved apps: Ghostty and AeroSpace are installed before OMacOS and must remain afterward"
  print "  Limits:        physical multi-monitor layout, TCC approvals, camera, microphone, and real input events still need a guarded hardware smoke test"
}

run_doctor() {
  local failures=0
  validate_vm_name "$base_vm" || (( failures += 1 ))
  validate_vm_name "$test_vm" || (( failures += 1 ))
  if [[ $(uname -m) == "arm64" ]]; then
    print "[ok] Apple Silicon host"
  else
    print -u2 "[fail] Tart macOS guests require an Apple Silicon host"
    (( failures += 1 ))
  fi

  local macos_major
  macos_major=$(sw_vers -productVersion | cut -d. -f1)
  if (( macos_major >= 27 )); then
    print "[ok] macOS 27 or newer host"
  else
    print -u2 "[fail] This automated provisioning path requires macOS 27 or newer"
    (( failures += 1 ))
  fi

  if command_is_available "$tart_command"; then
    print "[ok] Tart"
  else
    print -u2 "[fail] Tart is not installed. Install it with: brew install openai/tools/tart"
    (( failures += 1 ))
  fi

  local free_gib
  free_gib=$(available_storage_gib)
  if (( free_gib >= minimum_free_gib )); then
    print "[ok] $free_gib GiB free for VM storage"
  else
    print -u2 "[fail] $free_gib GiB free; at least $minimum_free_gib GiB is required"
    print -u2 "       Free local space or set TART_HOME to a fast external APFS volume."
    (( failures += 1 ))
  fi

  (( failures == 0 ))
}

confirm_action() {
  $assume_yes && return 0
  [[ -r /dev/tty ]] || {
    print -u2 "No interactive terminal is available. Re-run with --yes."
    return 2
  }
  print -n "Continue with the disposable VM operation? [y/N] "
  read -r answer </dev/tty
  [[ $answer == [yY] || $answer == [yY][eE][sS] ]]
}

wait_for_vm_ip() {
  local vm_name=$1
  local attempt ip_address
  for attempt in {1..180}; do
    ip_address=$("$tart_command" ip "$vm_name" 2>/dev/null || true)
    if [[ $ip_address == <->.<->.<->.<-> ]]; then
      print -r -- "$ip_address"
      return 0
    fi
    sleep 5
  done
  print -u2 "Timed out waiting for $vm_name to obtain an IP address."
  return 1
}

run_password_command() {
  OMACOS_VM_EXPECT_PASSWORD="$vm_password" /usr/bin/expect -f - -- "$@" <<'EXPECT'
set timeout 7200
set password $env(OMACOS_VM_EXPECT_PASSWORD)
set command [lrange $argv 0 end]
spawn {*}$command
expect {
  -re {(?i)password:} {
    send -- "$password\r"
    exp_continue
  }
  timeout {
    puts stderr "Timed out waiting for the VM command"
    exit 124
  }
  eof {
    catch wait result
    exit [lindex $result 3]
  }
}
EXPECT
}

ssh_arguments() {
  print -r -- \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile="$artifact_directory/known_hosts" \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=10
}

wait_for_ssh() {
  local ip_address=$1
  local attempt
  local -a options
  options=(${(f)"$(ssh_arguments)"})
  for attempt in {1..120}; do
    if run_password_command /usr/bin/ssh "${options[@]}" "$vm_user@$ip_address" /usr/bin/true >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done
  print -u2 "Timed out waiting for SSH in the macOS guest."
  return 1
}

start_vm_headless() {
  local vm_name=$1
  shift
  mkdir -p "$artifact_directory"
  "$tart_command" run "$vm_name" --no-graphics "$@" > "$artifact_directory/$vm_name-console.log" 2>&1 &
  print $!
}

stop_vm() {
  local vm_name=$1
  "$tart_command" stop "$vm_name" >/dev/null 2>&1 || true
}

prepare_base_vm() {
  run_doctor
  if vm_exists "$base_vm"; then
    print "Reusing prepared base VM $base_vm."
    return
  fi
  print_plan
  confirm_action || { print "VM preparation cancelled."; return 0; }

  print "Creating a clean macOS 27 base VM from Apple's latest restore image..."
  "$tart_command" create --from-ipsw=latest "$base_vm"

  local provision_options
  provision_options="fullName=OMacOS Test,username=$vm_user,password=$vm_password,logsInAutomatically=true,enablesRemoteLogin=true"
  print "Completing unattended first boot..."
  start_vm_headless "$base_vm" "--provisioning-opts=$provision_options" >/dev/null
  local ip_address
  ip_address=$(wait_for_vm_ip "$base_vm")
  wait_for_ssh "$ip_address"
  stop_vm "$base_vm"
  print "Prepared base VM $base_vm."
}

delete_test_vm() {
  validate_vm_name "$test_vm"
  if vm_exists "$test_vm"; then
    stop_vm "$test_vm"
    "$tart_command" delete "$test_vm"
  fi
}

archive_checkout() {
  local archive_path=$1
  /usr/bin/tar \
    --exclude=.git \
    --exclude=.build \
    --exclude=.artifacts \
    -czf "$archive_path" \
    -C "$project_root" .
}

run_lifecycle_test() {
  run_doctor
  vm_exists "$base_vm" || {
    print -u2 "Base VM $base_vm does not exist. Run '$0 prepare' first."
    return 1
  }
  print_plan
  confirm_action || { print "VM test cancelled."; return 0; }

  mkdir -p "$artifact_directory"
  delete_test_vm
  print "Creating a disposable stacked clone..."
  "$tart_command" clone --stacked "$base_vm" "$test_vm"
  trap 'stop_vm "$test_vm"' EXIT
  start_vm_headless "$test_vm" >/dev/null

  local ip_address
  ip_address=$(wait_for_vm_ip "$test_vm")
  wait_for_ssh "$ip_address"

  local source_archive="$artifact_directory/omacos-source.tar.gz"
  archive_checkout "$source_archive"
  local -a options
  options=(${(f)"$(ssh_arguments)"})
  print "Copying the current checkout into the guest..."
  run_password_command /usr/bin/scp "${options[@]}" \
    "$source_archive" \
    "$project_root/test/vm/guest-lifecycle.zsh" \
    "$vm_user@$ip_address:/tmp/"

  print "Running clean install, verification, uninstall, and baseline comparison..."
  set +e
  run_password_command /usr/bin/ssh -tt "${options[@]}" "$vm_user@$ip_address" \
    "/bin/zsh /tmp/guest-lifecycle.zsh /tmp/omacos-source.tar.gz" \
    | tee "$artifact_directory/guest-lifecycle.log"
  local guest_status=${pipestatus[1]}
  set -e

  stop_vm "$test_vm"
  trap - EXIT
  if (( guest_status == 0 )); then
    delete_test_vm
    print "OMacOS VM lifecycle test passed. Artifacts: $artifact_directory"
  else
    print -u2 "OMacOS VM lifecycle test failed. The stopped VM was kept as $test_vm for inspection."
    print -u2 "Artifacts: $artifact_directory"
    return $guest_status
  fi
}

for argument in "${@:2}"; do
  case $argument in
    --yes|-y) assume_yes=true ;;
    *) print -u2 "Unknown VM test option: $argument"; exit 2 ;;
  esac
done

case ${1:-plan} in
  plan) print_plan ;;
  doctor) run_doctor ;;
  prepare) prepare_base_vm ;;
  run) run_lifecycle_test ;;
  clean)
    run_doctor
    print_plan
    confirm_action || { print "VM cleanup cancelled."; exit 0; }
    delete_test_vm
    print "Removed disposable VM $test_vm. The reusable base VM was kept."
    ;;
  *)
    print -u2 "Usage: macos-vm-test.zsh <plan|doctor|prepare|run|clean> [--yes]"
    exit 2
    ;;
esac
