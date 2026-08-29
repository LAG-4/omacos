# Third-party notices

## Omarchy

The 22 bundled OMacOS semantic color palettes and parts of the shortcut vocabulary were adapted from [Omarchy](https://github.com/basecamp/omarchy) at the frozen Quattro reference commit recorded in `docs/quattro-inventory.json`. Omarchy wallpapers are not bundled because image licensing must be checked separately.

Copyright (c) David Heinemeier Hansson

Omarchy is distributed under the MIT License. The complete license text is preserved in [`licenses/OMARCHY-MIT.txt`](licenses/OMARCHY-MIT.txt).

## Installed applications

OMacOS installs third-party applications through Homebrew. Those applications are not relicensed by OMacOS. AeroSpace, Rift, yabai, Karabiner-Elements, Ghostty, JankyBorders, Homebrew, jq, and blueutil retain their upstream licenses and copyright notices. Rift and yabai are optional window-manager profiles and are not bundled in this repository.

The optional OMacOS Neovim profile fetches lazy.nvim, Tokyo Night, Telescope, plenary.nvim, nvim-tree, gitsigns.nvim, lualine.nvim, and toggleterm.nvim from their upstream repositories on first launch. Those plugins are not bundled or relicensed by OMacOS.

The Claude, Codex, and Fireworks usage collectors are adapted from Omarchy's agent-usage collectors under the MIT License. The complete Omarchy license text is included in `licenses/OMARCHY-MIT.txt`.

Applications listed in `config/optional-packages.json` are downloaded and installed by Homebrew only after an explicit user action. They are not bundled with OMacOS and retain their own licenses, update mechanisms, privacy prompts, and terms.
