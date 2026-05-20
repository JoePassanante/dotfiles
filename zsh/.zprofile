# Login-shell setup. Anything here also runs in interactive shells (via .zshrc),
# but only login shells source this file.

# Homebrew shellenv runs from .zshrc (with existence check) so this file stays
# minimal and platform-agnostic.

# JetBrains Toolbox scripts (mac path)
if [ -d "$HOME/Library/Application Support/JetBrains/Toolbox/scripts" ]; then
  export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
fi
# JetBrains Toolbox scripts (linux path)
if [ -d "$HOME/.local/share/JetBrains/Toolbox/scripts" ]; then
  export PATH="$PATH:$HOME/.local/share/JetBrains/Toolbox/scripts"
fi
