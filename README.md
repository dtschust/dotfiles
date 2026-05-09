# Drew's dotfiles

Portable macOS dotfiles and setup notes for a personal workstation.

This repository intentionally avoids machine-private material. Keep credentials,
private host files, package-manager auth files, and local-only setup in ignored
local files such as `~/.zshrc.local`.

## Layout

- `shell/`: zsh config and prompt theme
- `git/`: portable git config
- `vim/`: Vim defaults
- `tmux/`: tmux defaults
- `karabiner/`: Karabiner-Elements hyper-key mappings
- `hammerspoon/`: Hammerspoon automation
- `vscode/`: editor settings, keybindings, and extension list
- `iterm2/`: iTerm2 theme/profile notes
- `bettertouchtool/`: BetterTouchTool preset export and notes
- `macos/`: macOS defaults script
- `scripts/`: small AppleScript helpers

## Bootstrap

There is no one-shot bootstrap script in this repo. Install and review files
manually so machine-specific state stays out of git.

Suggested manual setup:

- Copy or symlink `shell/.zshrc` to `~/.zshrc`.
- Copy or symlink `git/.gitconfig` to `~/.gitconfig`.
- Copy or symlink `vim/.vimrc` to `~/.vimrc`.
- Copy or symlink `tmux/.tmux.conf` to `~/.tmux.conf`.
- Copy `karabiner/karabiner.json` to `~/.config/karabiner/karabiner.json`.
- Copy `hammerspoon/init.lua` to `~/.hammerspoon/init.lua`.
- Import iTerm2, Divvy, and BetterTouchTool settings through those apps.

Package and app installation is intentionally not tracked here. Keep package
lists in notes or regenerate them from the current machine when setting up a
new computer.
