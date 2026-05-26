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

# Make Linuxbrew visible to this script if it's installed but not yet on PATH
# (common right after first install on a fresh CDD).
if [ "$OS" = linux ] && [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ---------------------------------------------- pick a package installer once
# Prefer brew (Homebrew on mac, Linuxbrew on linux) since it's the only
# manager that has every tool we need (stow, mise, zsh-autosuggestions,
# zsh-syntax-highlighting). On distros where brew isn't installed and we
# can't use it (e.g. Amazon Linux 2023, where EPEL is officially discouraged),
# fall back to the native manager only for tools it actually has.
HAS_BREW=0
command -v brew >/dev/null 2>&1 && HAS_BREW=1

# Returns 0 if a brew formula is available in any tap.
# Cheaper than `brew search`: checks only the formula list cache.
brew_install() {
  local pkg="$1"
  brew list "$pkg" >/dev/null 2>&1 && return 0
  brew install "$pkg"
}

# ---------------------------------------------------------------- ensure brew
# We expect the user to install brew themselves so they can read the upstream
# warnings, choose where it lives, and answer its prompts. Bailing out also
# avoids running the brew install one-liner inside `set -e` in a sub-shell,
# which has a history of exiting half-installed.
ensure_brew() {
  if [ "$HAS_BREW" = 1 ]; then return; fi
  if [ "$OS" = mac ]; then
    cat >&2 <<'EOF'
ERROR: Homebrew is not installed.

Install it first, then re-run this script:

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"

See https://brew.sh for details.
EOF
  else
    cat >&2 <<'EOF'
ERROR: Linuxbrew is not installed.

Install it first, then re-run this script:

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

See https://docs.brew.sh/Homebrew-on-Linux for details.
On Amazon dev desktops, see https://w.amazon.com/bin/view/Main/LinuxBrewOnCloudDesktop/.
EOF
  fi
  exit 1
}

# ---------------------------------------------------------------- ensure stow
ensure_stow() {
  if command -v stow >/dev/null 2>&1; then return; fi
  echo "==> stow not found — installing"
  ensure_brew
  brew_install stow
}

ensure_stow

# ----------------------------------------------------------- ensure mise
ensure_mise() {
  if command -v mise >/dev/null 2>&1; then return; fi
  echo "==> mise not found — installing"
  ensure_brew
  brew_install mise
}
ensure_mise

# ------------------------------------- ensure CLI tools nvim & shell expect
# tree-sitter: nvim-treesitter parser builds
# ripgrep, fd: telescope live_grep / find_files
# lazygit: neogit alternative, used by some plugins
# gcc: fallback C compiler for treesitter parsers without prebuilt binaries
# fzf: PSFzf-equivalent fuzzy history/file search
ensure_dev_tools() {
  ensure_brew
  for pkg in tree-sitter ripgrep fd lazygit gcc fzf; do
    brew_install "$pkg"
  done
}
ensure_dev_tools

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
  ensure_brew
  brew_install zsh-autosuggestions
  brew_install zsh-syntax-highlighting
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
