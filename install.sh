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

# ----------------------------------------------------------- ensure mise
# mise manages node/python/rust versions. The mise package below pins them.
ensure_mise() {
  if command -v mise >/dev/null 2>&1; then return; fi
  echo "==> mise not found — installing"
  if [ "$OS" = mac ]; then
    brew install mise
  else
    if   command -v apt-get >/dev/null 2>&1; then
      # Ubuntu/Debian: official mise repo.
      sudo install -dm 755 /etc/apt/keyrings
      curl -fsSL https://mise.jdx.dev/gpg-key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
      echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list
      sudo apt-get update && sudo apt-get install -y mise
    elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y mise || curl https://mise.run | sh
    elif command -v pacman  >/dev/null 2>&1; then sudo pacman -S --noconfirm mise
    else curl https://mise.run | sh
    fi
  fi
}
ensure_mise

# ------------------------------------------------- ensure JetBrainsMono Nerd Font
# Used by .wezterm.lua and nvim plugins (neo-tree, gitsigns, etc.).
ensure_nerd_font() {
  local font_name="JetBrainsMono Nerd Font"
  if [ "$OS" = mac ]; then
    if ls ~/Library/Fonts/JetBrainsMonoNerdFont* >/dev/null 2>&1 \
      || ls /Library/Fonts/JetBrainsMonoNerdFont* >/dev/null 2>&1; then
      return
    fi
    echo "==> Installing $font_name"
    brew install --cask font-jetbrains-mono-nerd-font
  else
    local font_dir="$HOME/.local/share/fonts"
    if ls "$font_dir"/JetBrainsMonoNerdFont* >/dev/null 2>&1; then return; fi
    echo "==> Installing $font_name to $font_dir"
    mkdir -p "$font_dir"
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/jbm.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -q "$tmp/jbm.zip" -d "$tmp/jbm"
    cp "$tmp"/jbm/*.ttf "$font_dir"/ 2>/dev/null || true
    rm -rf "$tmp"
    if command -v fc-cache >/dev/null 2>&1; then fc-cache -f "$font_dir" >/dev/null; fi
  fi
}
ensure_nerd_font

# ----------------------------------------------------------- ensure zsh plugins
# zsh-autosuggestions and zsh-syntax-highlighting. Sourced from .zshrc which
# probes a few well-known install paths.
ensure_zsh_plugins() {
  if ! command -v zsh >/dev/null 2>&1; then return; fi
  echo "==> Ensuring zsh plugins (autosuggestions + syntax-highlighting)"
  if [ "$OS" = mac ]; then
    brew list zsh-autosuggestions     >/dev/null 2>&1 || brew install zsh-autosuggestions
    brew list zsh-syntax-highlighting >/dev/null 2>&1 || brew install zsh-syntax-highlighting
  else
    if   command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y zsh-autosuggestions zsh-syntax-highlighting
    elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y zsh-autosuggestions zsh-syntax-highlighting
    elif command -v pacman  >/dev/null 2>&1; then sudo pacman -S --noconfirm zsh-autosuggestions zsh-syntax-highlighting
    elif command -v zypper  >/dev/null 2>&1; then sudo zypper install -y zsh-autosuggestions zsh-syntax-highlighting
    elif command -v apk     >/dev/null 2>&1; then sudo apk add zsh-autosuggestions zsh-syntax-highlighting
    else echo "  No supported package manager — skipping zsh plugins."
    fi
  fi
}
ensure_zsh_plugins

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
backup_one "$HOME/.config/mise/config.toml"

# ---------------------------------------------------------- decide packages
# zsh package only useful where zsh is the real shell.
PACKAGES=(wezterm git nvim mise)
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
