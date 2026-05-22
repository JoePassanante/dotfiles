# PowerShell 7 profile — gives a zsh-like interactive experience.
# Linked into $PROFILE by install.ps1. Edit the dotfiles copy, not this one.

# ---------- PSReadLine: zsh-autosuggestions + zsh-syntax-highlighting equivalents ----------
# PSReadLine ships with PowerShell 7. Make sure we have a recent version.
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine

    # Inline ghost-grey suggestion from history. Press -> (Right Arrow) or End to accept,
    # exactly like zsh-autosuggestions.
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle InlineView

    # Persist history across sessions (PSReadLine does this by default; cap size).
    Set-PSReadLineOption -MaximumHistoryCount 100000
    Set-PSReadLineOption -HistoryNoDuplicates:$true
    Set-PSReadLineOption -HistorySaveStyle SaveIncrementally

    # Syntax-highlighting colors. PSReadLine paints commands/parameters/strings as you type.
    Set-PSReadLineOption -Colors @{
        Command          = 'Green'
        Parameter        = 'Cyan'
        Operator         = 'Magenta'
        Variable         = 'Yellow'
        String           = 'Blue'
        Number           = 'Magenta'
        Comment          = 'DarkGray'
        InlinePrediction = 'DarkGray'
        Error            = 'Red'
    }

    # Up/Down arrow do prefix-based history search (type "git " then ↑ to walk only
    # past git commands).
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Tab completion: menu instead of cycling through one-at-a-time.
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

# ---------- PSFzf: Ctrl+R fuzzy history, Ctrl+T fuzzy files (mirrors fzf in zsh) ----------
if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# ---------- oh-my-posh: starship-equivalent prompt ----------
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    # Use a built-in theme. Run `Get-PoshThemes` to browse alternatives.
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression
}

# ---------- mise (runtime version manager) ----------
if (Get-Command mise -ErrorAction SilentlyContinue) {
    mise activate pwsh | Out-String | Invoke-Expression
}

# ---------- Aliases / shortcuts ----------
# PowerShell aliases can only point at a single command, so for arg-bearing
# shortcuts use a function instead.
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force -Hidden @args }
function .. { Set-Location .. }
function ...  { Set-Location ../.. }

# Source machine-local overrides if present (work-specific paths, secrets).
$localProfile = Join-Path $HOME 'Microsoft.PowerShell_profile.local.ps1'
if (Test-Path $localProfile) { . $localProfile }
