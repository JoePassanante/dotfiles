#!/usr/bin/env bash
# Symlink every package in this repo into $HOME using GNU stow.
# Run from the repo root: ./install.sh
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v stow >/dev/null 2>&1; then
  echo "stow not found. Install with: brew install stow  (mac)  |  apt install stow  (linux)"
  exit 1
fi

# Each top-level directory is a stow "package". Stow recreates its internal
# layout under $HOME, e.g. zsh/.zshrc -> ~/.zshrc.
for pkg in */; do
  pkg="${pkg%/}"
  echo "stow: $pkg"
  stow --target="$HOME" --restow "$pkg"
done

echo
echo "Done. If you have machine-specific zsh config, drop it in ~/.zshrc.local"
echo "(loaded automatically by ~/.zshrc, not tracked in git)."
