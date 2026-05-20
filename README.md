# dotfiles

Cross-machine configs for the tools I use daily.

## Layout

Each top-level directory is a [GNU stow](https://www.gnu.org/software/stow/) package whose contents mirror `$HOME`. Stow turns each file inside into a symlink at the matching path.

```
dotfiles/
├── git/
│   └── .gitconfig                  -> ~/.gitconfig
├── nvim/
│   └── .config/nvim/               -> ~/.config/nvim/
├── wezterm/
│   └── .wezterm.lua                -> ~/.wezterm.lua
└── zsh/
    ├── .zshenv                     -> ~/.zshenv
    ├── .zprofile                   -> ~/.zprofile
    └── .zshrc                      -> ~/.zshrc
```

## Install

```sh
git clone https://github.com/<you>/dotfiles ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` runs `stow --restow <pkg>` for every top-level directory.

To install just one package:

```sh
stow --target="$HOME" wezterm
```

To uninstall a package (remove the symlinks):

```sh
stow --target="$HOME" -D wezterm
```

## Machine-local overrides

`.zshrc` ends with:

```sh
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
```

Put work-specific aliases, internal hostnames, or anything else that shouldn't be public into `~/.zshrc.local`. It's gitignored and stays on the machine.

## Requirements

- `stow` — `brew install stow` on macOS, `apt install stow` on Debian/Ubuntu.
- `mise` — referenced by `.zshrc` for runtime version management. Install with `brew install mise` or skip the `mise activate` line.
