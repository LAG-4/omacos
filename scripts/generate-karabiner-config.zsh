#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
project_root=${script_directory:h}
keybinding_ledger=${1:-$project_root/config/keybindings.json}
output_path=${2:-$project_root/config/karabiner/omacos-super-key.json}

if ! command -v jq >/dev/null 2>&1; then
  print -u2 "OMacOS keybinding generation requires jq"
  exit 1
fi

mkdir -p "${output_path:h}"

jq '
  def leader_manipulator:
    {
      type: "basic",
      from: {
        key_code: .leaderKey,
        modifiers: { optional: ["any"] }
      },
      to: [
        { set_variable: { name: "omacos_super_key", value: 1 } },
        { shell_command: ("/bin/zsh -lc " + ("$HOME/.local/bin/omacos pointer super-down" | @sh)) }
      ],
      to_after_key_up: [
        { set_variable: { name: "omacos_super_key", value: 0 } },
        { shell_command: ("/bin/zsh -lc " + ("$HOME/.local/bin/omacos pointer super-up" | @sh)) }
      ],
      to_if_alone: [
        { key_code: .leaderKey }
      ]
    };

  def binding_manipulator:
    {
      type: "basic",
      description: .description,
      from: (
        { key_code: .key }
        + if (.modifiers | length) > 0
          then { modifiers: { mandatory: .modifiers } }
          else {}
          end
      ),
      conditions: [
        { type: "variable_if", name: "omacos_super_key", value: 1 }
      ],
      to: (
        if has("output") then
          [{ key_code: .output.key, modifiers: (.output.modifiers // []) }]
        else
          [{ shell_command: ("/bin/zsh -lc " + (.command | @sh)) }]
        end
      )
    };

  def global_binding_manipulator:
    (
      {
        type: "basic",
        description: .description,
        from: (
          { key_code: .key }
          + if has("modifiers")
            then { modifiers: { mandatory: .modifiers } }
            else { modifiers: { optional: ["any"] } }
            end
        ),
        to: [
          { shell_command: ("/bin/zsh -lc " + ((.keyDownCommand // .command) | @sh)) }
        ]
      }
      + if has("keyUpCommand") then
          { to_after_key_up: [{ shell_command: ("/bin/zsh -lc " + (.keyUpCommand | @sh)) }] }
        else {}
        end
    );

  def pointer_binding_manipulator:
    {
      type: "basic",
      description: .description,
      from: {
        pointing_button: .button,
        modifiers: { optional: ["any"] }
      },
      conditions: [
        { type: "variable_if", name: "omacos_super_key", value: 1 }
      ],
      to: [
        { shell_command: ("/bin/zsh -lc " + (.beginCommand | @sh)) }
      ],
      to_after_key_up: [
        { shell_command: ("/bin/zsh -lc " + (.endCommand | @sh)) }
      ]
    };

  {
    title: "OMacOS Super key",
    rules: [
      {
        description: "Use Right Option as the OMacOS Super layer",
        manipulators: ([leader_manipulator] + [.bindings[] | binding_manipulator])
      },
      {
        description: "Hold F9 for OMacOS dictation",
        manipulators: [(.globalBindings // [])[] | global_binding_manipulator]
      },
      {
        description: "Use OMacOS Super with pointer gestures",
        manipulators: [(.pointerBindings // [])[] | select(has("button")) | pointer_binding_manipulator]
      }
    ]
  }
' "$keybinding_ledger" > "$output_path"

print "Generated Karabiner profile: $output_path"
