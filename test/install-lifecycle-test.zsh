#!/bin/zsh

set -euo pipefail

test_directory=${0:A:h}
project_root=${test_directory:h}
temporary_home=$(mktemp -d -t omacos-lifecycle-test.XXXXXX)
trap 'rm -rf "$temporary_home"' EXIT

mkdir -p "$temporary_home/.config/aerospace"
print "original dot config" > "$temporary_home/.aerospace.toml"
print "original xdg config" > "$temporary_home/.config/aerospace/aerospace.toml"

OMACOS_TEST_HOME="$temporary_home" OMACOS_TEST_MODE=true "$project_root/install.sh" --yes >/dev/null

if [[ ! -x $temporary_home/.local/bin/omacos-shell ]]; then
  print -u2 "Install lifecycle test failed: native shell was not installed"
  exit 1
fi

if [[ ! -L $temporary_home/.local/bin/omacos ]]; then
  print -u2 "Install lifecycle test failed: CLI link was not installed"
  exit 1
fi

if [[ -f $temporary_home/.aerospace.toml ]]; then
  print -u2 "Install lifecycle test failed: ambiguous dot AeroSpace config remains"
  exit 1
fi

installed_root="$temporary_home/.local/share/omacos/current"
mkdir -p "$temporary_home/test-bin"
cat > "$temporary_home/test-bin/aerospace" <<'EOF'
#!/bin/zsh
exit 0
EOF
chmod +x "$temporary_home/test-bin/aerospace"
PATH="$temporary_home/test-bin:$PATH" OMACOS_TEST_HOME="$temporary_home" OMACOS_ROOT="$installed_root" "$temporary_home/.local/bin/omacos" doctor >/dev/null
print y | OMACOS_TEST_HOME="$temporary_home" OMACOS_ROOT="$installed_root" "$temporary_home/.local/bin/omacos" uninstall >/dev/null

if [[ $(<"$temporary_home/.aerospace.toml") != "original dot config" ]]; then
  print -u2 "Install lifecycle test failed: dot AeroSpace config was not restored"
  exit 1
fi

if [[ $(<"$temporary_home/.config/aerospace/aerospace.toml") != "original xdg config" ]]; then
  print -u2 "Install lifecycle test failed: XDG AeroSpace config was not restored"
  exit 1
fi

if [[ -e $temporary_home/.local/share/omacos/current || -e $temporary_home/.local/bin/omacos-shell ]]; then
  print -u2 "Install lifecycle test failed: installed files remain after uninstall"
  exit 1
fi

print "Install and uninstall lifecycle test passed"
