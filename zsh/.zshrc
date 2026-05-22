export GIT_DISCOVERY_ACROSS_FILESYSTEM=1

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000000
SAVEHIST=10000000
setopt BANG_HIST                 # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS          # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found.
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space.
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file.
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry.
setopt HIST_VERIFY               # Don't execute immediately upon history expansion.
setopt HIST_BEEP                 # Beep when accessing nonexistent history.

# Helper: prepend $1 to PATH only if the directory exists.
path_prepend() { [ -d "$1" ] && export PATH="$1:$PATH"; }
path_append()  { [ -d "$1" ] && export PATH="$PATH:$1"; }

# Cross-platform paths
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.gitcleanup"

# ---------- macOS-specific ----------
if [[ "$OSTYPE" == "darwin"* ]]; then
  # Homebrew (Apple Silicon)
  if [ -d /opt/homebrew/bin ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    path_prepend "/opt/homebrew/opt/openssl@3.0/bin"
    if [ -d /opt/homebrew/opt/libffi ]; then
      export PKG_CONFIG_PATH="/opt/homebrew/opt/libffi/lib/pkgconfig"
      export LDFLAGS="-L/opt/homebrew/opt/libffi/lib"
      export CPPFLAGS="-I/opt/homebrew/opt/libffi/include"
    fi
  fi
  # VS Code `code` command
  path_append "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  # Android SDK (mac default location)
  export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
fi

# ---------- Linux-specific ----------
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linuxbrew, if present
  if [ -d /home/linuxbrew/.linuxbrew/bin ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
  # Android SDK (linux default location)
  export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
fi

# ---------- Android SDK (shared, gated on dir existence) ----------
if [ -d "$ANDROID_SDK_ROOT" ]; then
  export ANDROID_HOME=$ANDROID_SDK_ROOT
  path_append "$ANDROID_SDK_ROOT/emulator"
  path_append "$ANDROID_SDK_ROOT/tools"
  path_append "$ANDROID_SDK_ROOT/tools/bin"
  path_append "$ANDROID_SDK_ROOT/platform-tools"
  path_append "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
fi

# ---------- mise (runtime version manager) ----------
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
  rtx() { mise "$@"; }
fi

# ---------- Functions ----------

# Run an adb subcommand against every connected device.
adb-all() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: adb-all <adb subcommand> [args...]"
    return 1
  fi
  local devices
  devices=($(adb devices | awk '$2=="device"{print $1}'))
  for serial in $devices; do
    echo "→ $serial"
    adb -s "$serial" "$@"
  done
}

# Append a new alias to ~/.zshrc and enable it now.
addalias() {
  if [ $# -eq 2 ]; then
    echo "alias $1='$2'" >> ~/.zshrc
    alias "$1=$2"
    echo "Alias $1='$2' added successfully."
  else
    echo "Usage: addalias <alias_name> '<command>'"
  fi
}

# Interactively prune remote branches whose latest commit is older than $1 (a date).
clean_branches() {
    local filter_date="$1"
    git fetch
    for branch in $(git branch -r | grep -v HEAD); do
        branch_name="${branch#origin/}"
        last_commit_date=$(git show -s --format=%ci $branch)
        if [[ -z "$filter_date" ]] || [[ "$last_commit_date" < "$filter_date" ]]; then
            echo -n "$branch_name $last_commit_date (y/n)? "
            read answer
            if [ "$answer" = "y" ]; then
                git push origin --delete "$branch_name" && echo "Deleted $branch_name" || echo "Error deleting $branch_name"
            fi
        fi
    done
}

# Convert a CSV file to a Markdown table.
csv2md() {
  [ -z "$1" ] && echo "Please provide a CSV file location." || {
    output="${1%.csv}.md";
    echo -n "| " > "$output";
    head -n 1 "$1" | tr ',' '\n' | awk 'NF { printf "| %s |", $0 }' >> "$output";
    echo -n "\n| " >> "$output";
    head -n 1 "$1" | tr ',' '\n' | awk 'NF { printf "| --- |" }' >> "$output";
    echo "" >> "$output";
    tail -n +2 "$1" | sed 's/,/ | /g;s/^/| /;s/$/ |/' >> "$output" && echo "CSV file '$1' has been converted to Markdown table in '$output'.";
  };
}

# ---------- Aliases ----------
alias scrcpy='scrcpy'
alias view-android='scrcpy'

# ---------- Plugins ----------
# zsh-autosuggestions: ghost-grey command suggestions from history.
# Press → (Right Arrow) or End to accept.
for f in \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
do
  [ -r "$f" ] && source "$f" && break
done

# zsh-syntax-highlighting: green for valid commands, red for invalid, plus
# string/option/redirect highlighting. Per its README this MUST be the last
# plugin sourced (it hooks into the line editor).
for f in \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
do
  [ -r "$f" ] && source "$f" && break
done

# Source machine-local overrides (work-specific aliases, internal hostnames, secrets).
# This file is intentionally not tracked in git.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
