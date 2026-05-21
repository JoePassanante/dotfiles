# dotfiles

Cross-platform configs for the tools I use daily.

## Install

One command per platform. Each script auto-detects what's needed and skips packages that don't apply (e.g. zsh on Windows).

### macOS / Linux

```sh
git clone https://github.com/JoePassanante/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh
```

The script installs `stow` if missing (via Homebrew on mac; `apt`/`dnf`/`pacman`/`zypper`/`apk` on Linux), backs up any existing real files in `$HOME`, then symlinks every package.

### Windows (native — no WSL)

```powershell
git clone https://github.com/JoePassanante/dotfiles $HOME\dotfiles
cd $HOME\dotfiles
.\install.ps1
```

Symlink creation on Windows requires either **Developer Mode** (Settings → Privacy & security → For developers) **or** running PowerShell as Administrator. The script checks first and tells you which to do.

## What gets linked where

| Package  | Linked to (mac / linux)             | Linked to (windows)               |
| -------- | ----------------------------------- | --------------------------------- |
| wezterm  | `~/.wezterm.lua`                    | `$HOME\.wezterm.lua`              |
| git      | `~/.gitconfig`                      | `$HOME\.gitconfig`                |
| nvim     | `~/.config/nvim`                    | `$env:LOCALAPPDATA\nvim`          |
| mise     | `~/.config/mise/config.toml`        | `$env:APPDATA\mise\config.toml`   |
| zsh      | `~/.zshrc`, `.zshenv`, `.zprofile`  | *(skipped — no native zsh)*       |

The installer also installs **JetBrainsMono Nerd Font** (used by wezterm and nvim plugins) and **mise** if missing.

## Cross-platform behavior

- **`.zshrc`** branches on `$OSTYPE`. Mac-only paths (`/opt/homebrew`, `/Applications/...`, `~/Library/Android/sdk`) only run on mac; linux equivalents run on linux. Tools like `mise` are activated only when present.
- **`.wezterm.lua`** detects `wezterm.target_triple` and uses `CMD` as the modifier on macOS, `CTRL` on Linux/Windows. Same shortcuts otherwise — muscle memory transfers.
- **`install.sh`** skips the `zsh` package if zsh isn't installed.

## Machine-local overrides

`.zshrc` ends with:

```sh
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
```

Put work-specific aliases, internal hostnames, secrets, etc. into `~/.zshrc.local`. It's gitignored and stays on the machine.

## Removing the symlinks

```sh
cd ~/dotfiles
stow --target="$HOME" -D wezterm zsh git nvim
```

(Windows: delete the symlinks manually, or restore from `~/.dotfiles-backup-*`.)
