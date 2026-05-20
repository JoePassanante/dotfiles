#!/usr/bin/env bash
# One-step installer for macOS and Linux.
# - Detects OS and package manager
# - Ensures git + stow are installed
# - Symlinks every package in this repo into $HOME
#
# Run from the repo root: ./install.sh
set -euo pipefail

cd "$(dirname "$0")"
REPO_DIR="$(pwd)"

OS="$(uname -s)"
case "$OS" in
  Darwin) OS=mac ;;
  Linux)  OS=linux ;;
  *) echo "Unsupported OS for install.sh: $OS — use install.ps1 on Windows."; exit 1 ;;
esac

echo "==> OS: $OS"

# ---------------------------------------------------------------- ensure stow
ensure_stow() {
  if command -v stow >/dev/null 2>&1; then return; fi
  echo "==> stow not found — installing"
  if [ "$OS" = mac ]; then
    if ! command -v brew >/dev/null 2>&1; then
      echo "Installing Homebrew first..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    brew install stow
  else
    if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y stow
    elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y stow
    elif command -v pacman  >/dev/null 2>&1; then sudo pacman -S --noconfirm stow
    elif command -v zypper  >/dev/null 2>&1; then sudo zypper install -y stow
    elif command -v apk     >/dev/null 2>&1; then sudo apk add stow
    else echo "Could not detect package manager. Install GNU stow manually, then re-run."; exit 1
    fi
  fi
}

ensure_stow

# -------------------------------------------------------- back up real files
# stow refuses to overwrite a real file with a symlink. Move any conflicting
# real files (not symlinks) out of the way before stowing.
backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
backed_up=0
backup_one() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mkdir -p "$backup_dir"
    mv "$target" "$backup_dir/"
    echo "  backed up $target -> $backup_dir/"
    backed_up=1
  fi
}
echo "==> Checking for existing real files in \$HOME..."
backup_one "$HOME/.zshrc"
backup_one "$HOME/.zshenv"
backup_one "$HOME/.zprofile"
backup_one "$HOME/.gitconfig"
backup_one "$HOME/.wezterm.lua"
backup_one "$HOME/.config/nvim"

# ---------------------------------------------------------- decide packages
# zsh package only useful where zsh is the real shell.
PACKAGES=(wezterm git nvim)
if command -v zsh >/dev/null 2>&1; then
  PACKAGES+=(zsh)
else
  echo "==> zsh not installed — skipping zsh package."
fi

# ------------------------------------------------------------------- stow
echo "==> Linking packages into \$HOME"
for pkg in "${PACKAGES[@]}"; do
  echo "  stow: $pkg"
  stow --target="$HOME" --restow "$pkg"
done

echo
echo "Done."
[ $backed_up -eq 1 ] && echo "Existing files were moved to: $backup_dir"
echo "If you have machine-specific zsh config, drop it in ~/.zshrc.local"
echo "(loaded automatically by ~/.zshrc, gitignored)."
