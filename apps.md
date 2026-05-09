# Mac Setup Notes

## First Run

- Install Homebrew: <https://brew.sh/>
- Run `brew bundle` from this repository.
- Install Oh My Zsh: <https://ohmyz.sh/>
- Run `$(brew --prefix)/opt/fzf/install` for shell key bindings and completion.
- Run `./bootstrap.sh --dry-run`, then `./bootstrap.sh --link` or `./bootstrap.sh --copy`.

## Manual App Imports

- Karabiner-Elements: import `karabiner/karabiner.json`.
- Hammerspoon: load `hammerspoon/init.lua` and grant Accessibility permissions.
- iTerm2: import `iterm2/drews-theme.itermcolors`; see `iterm2/README.md`.
- BetterTouchTool: import `bettertouchtool/Default.bttpreset`; see `bettertouchtool/README.md`.
- Divvy: copy `divvy/com.mizage.Divvy.plist` to `~/Library/Preferences/` if needed.
- VS Code or Cursor: copy or merge `vscode/settings.json` and `vscode/keybindings.json`.

## Manual System Preferences

- Enable Accessibility permissions for Hammerspoon, Karabiner-Elements, BetterTouchTool, Divvy, and window-management tools.
- Enable scroll gesture zoom with Control as the modifier.
- Configure browser content blockers manually.
- Set up backups separately.
- Set up Obsidian vaults separately.
- Review `macos/defaults.sh` before running it; it changes global macOS defaults.

## Keep Out Of This Repo

- Credentials, certificates, package-manager auth, app auth databases, private host files, and machine-specific work setup.
- Generated shell history, editor history, app logs, and local cache files.
- Whole-app preference exports that contain account state, local paths, or opaque binary data. Prefer small sanitized exports plus notes.
