#!/usr/bin/env bash
# Bootstrap script for this nvim config on macOS and Linux.
# Installs system dependencies required by the plugins in init.lua.
# Safe to re-run; skips anything already present.

set -euo pipefail

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

OS="$(uname -s)"

install_macos() {
  if ! have brew; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  log "Installing CLI tools via Homebrew"
  brew install neovim ripgrep fd git node python rustup-init make
  have rustup || rustup-init -y --default-toolchain stable --profile default
}

install_linux() {
  if have apt-get; then
    log "Installing CLI tools via apt"
    sudo apt-get update
    sudo apt-get install -y neovim ripgrep fd-find git curl build-essential nodejs npm python3 python3-pip
    # fd is installed as `fdfind` on Debian/Ubuntu — link it so telescope finds it
    if ! have fd && have fdfind; then
      mkdir -p "$HOME/.local/bin"
      ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    fi
  elif have dnf; then
    log "Installing CLI tools via dnf"
    sudo dnf install -y neovim ripgrep fd-find git nodejs python3 python3-pip make gcc
  elif have pacman; then
    log "Installing CLI tools via pacman"
    sudo pacman -S --needed --noconfirm neovim ripgrep fd git nodejs npm python python-pip base-devel
  else
    warn "Unsupported Linux distro; install manually: neovim ripgrep fd git node python make"
    exit 1
  fi

  if ! have rustup; then
    log "Installing rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
    # shellcheck disable=SC1091
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
  fi
}

case "$OS" in
  Darwin) install_macos ;;
  Linux)  install_linux ;;
  *) warn "Unsupported OS: $OS"; exit 1 ;;
esac

# rustfmt + clippy are rust components, not Mason packages
if have rustup; then
  log "Ensuring rustfmt and clippy are installed"
  rustup component add rustfmt clippy || true
fi

# Optional: Claude Code CLI (required for claudecode.nvim)
if ! have claude; then
  warn "Claude Code CLI ('claude') not found in PATH."
  warn "Install from: https://docs.claude.com/en/docs/claude-code"
fi

# Optional: Kiro CLI
if ! have kiro; then
  warn "Kiro CLI ('kiro') not found in PATH."
  warn "Install: curl -fsSL https://cli.kiro.dev/install | bash"
fi

log "Running :checkhealth headlessly as a smoke test"
nvim --headless -c 'checkhealth' -c 'qa' 2>&1 | tail -20 || true

log "Done. Launch nvim — Lazy will install plugins, Mason will install LSPs/formatters on first run."
