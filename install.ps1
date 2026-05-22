# One-step installer for native Windows.
# - Symlinks each portable package into the right location under $HOME / $env:LOCALAPPDATA
# - Skips zsh (Windows has no native zsh and we are not using WSL)
#
# Symlink creation needs either:
#   - Developer Mode enabled (Settings -> Privacy & security -> For developers), OR
#   - An elevated (Run as Administrator) PowerShell session.
# The script detects this and tells you what to do.
#
# Usage:
#   PS> cd path\to\dotfiles
#   PS> .\install.ps1

$ErrorActionPreference = 'Stop'

$repo = $PSScriptRoot
Write-Host "==> Repo: $repo"

# Verify we can create symlinks. Try a tiny one in a temp dir; if it fails,
# bail with instructions instead of leaving a half-installed setup.
function Test-CanSymlink {
    $probeDir = Join-Path $env:TEMP ("dotfiles-symlink-probe-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $probeDir | Out-Null
    try {
        $target = Join-Path $probeDir "target.txt"
        Set-Content -Path $target -Value "x"
        $link = Join-Path $probeDir "link.txt"
        New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    } finally {
        Remove-Item -Recurse -Force $probeDir -ErrorAction SilentlyContinue
    }
}

if (-not (Test-CanSymlink)) {
    Write-Error @"
This shell cannot create symbolic links. Either:
  1. Enable Developer Mode (Settings -> Privacy & security -> For developers), OR
  2. Re-run this script in a PowerShell launched as Administrator.
"@
}

# ------------------------------------------------------- ensure JetBrainsMono Nerd Font
function Test-FontInstalled {
    $userFont = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $sysFont  = Join-Path $env:WINDIR 'Fonts'
    return ((Test-Path $userFont) -and (Get-ChildItem $userFont -Filter 'JetBrainsMonoNerdFont*' -ErrorAction SilentlyContinue)) `
        -or ((Test-Path $sysFont)  -and (Get-ChildItem $sysFont  -Filter 'JetBrainsMonoNerdFont*' -ErrorAction SilentlyContinue))
}
if (-not (Test-FontInstalled)) {
    Write-Host "==> Installing JetBrainsMono Nerd Font"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id DEVCOM.JetBrainsMonoNerdFont -e --silent --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop bucket add nerd-fonts 2>$null
        scoop install nerd-fonts/JetBrainsMono-NF
    } else {
        Write-Warning "Neither winget nor scoop found. Install JetBrainsMono Nerd Font manually from https://www.nerdfonts.com/font-downloads"
    }
}

# ----------------------------------------------------------------- ensure mise
if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing mise"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id jdx.mise -e --silent --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install mise
    } else {
        Write-Warning "Neither winget nor scoop found. Install mise manually from https://mise.jdx.dev/"
    }
}

# ------------------------------------------------------ ensure PowerShell 7 (pwsh)
# Windows ships PowerShell 5.1 by default. We want 7.x for modern PSReadLine.
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing PowerShell 7"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Microsoft.PowerShell -e --silent --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install pwsh
    } else {
        Write-Warning "Install PowerShell 7 manually from https://aka.ms/powershell"
    }
}

# ----------------------------------- ensure pwsh modules: PSReadLine, PSFzf, oh-my-posh
# Install for the current user only — no admin required.
function Ensure-Module($name) {
    if (-not (Get-Module -ListAvailable -Name $name)) {
        Write-Host "==> Installing PowerShell module: $name"
        Install-Module -Name $name -Scope CurrentUser -Force -AcceptLicense -ErrorAction SilentlyContinue
    }
}
Ensure-Module PSReadLine
Ensure-Module PSFzf

# oh-my-posh ships as a winget/scoop package, not a PS module.
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing oh-my-posh"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id JanDeDobbeleer.OhMyPosh -e --silent --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install oh-my-posh
    }
}

# fzf binary (PSFzf depends on it)
if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing fzf"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id junegunn.fzf -e --silent --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install fzf
    }
}

# Pairs of (repo-relative source, absolute destination).
$home_path = $HOME
$nvim_dest = Join-Path $env:LOCALAPPDATA 'nvim'
# mise on Windows reads ~\AppData\Roaming\mise\config.toml.
$mise_dest = Join-Path $env:APPDATA 'mise\config.toml'
# pwsh 7 profile path: $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1.
# (Windows PowerShell 5.1 uses WindowsPowerShell\, which we deliberately don't
# touch — pwsh 7 is what we configure.)
$pwsh_dest = Join-Path $home_path 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'

$links = @(
    @{ Src = (Join-Path $repo 'wezterm\.wezterm.lua');         Dst = (Join-Path $home_path '.wezterm.lua') },
    @{ Src = (Join-Path $repo 'git\.gitconfig');               Dst = (Join-Path $home_path '.gitconfig') },
    @{ Src = (Join-Path $repo 'nvim\.config\nvim');            Dst = $nvim_dest },
    @{ Src = (Join-Path $repo 'mise\.config\mise\config.toml'); Dst = $mise_dest },
    @{ Src = (Join-Path $repo 'pwsh\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'); Dst = $pwsh_dest }
)

$backupDir = Join-Path $home_path (".dotfiles-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$backedUp = $false

function Backup-IfReal($path) {
    if (Test-Path $path) {
        $item = Get-Item $path -Force
        $isLink = $item.Attributes -band [IO.FileAttributes]::ReparsePoint
        if (-not $isLink) {
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir | Out-Null
            }
            $leaf = Split-Path $path -Leaf
            Move-Item -Path $path -Destination (Join-Path $backupDir $leaf) -Force
            Write-Host "  backed up $path -> $backupDir\"
            $script:backedUp = $true
        } else {
            # Existing symlink — remove so we can re-create.
            Remove-Item -Force $path
        }
    }
}

foreach ($pair in $links) {
    $src = $pair.Src
    $dst = $pair.Dst

    if (-not (Test-Path $src)) {
        Write-Warning "Source missing, skipping: $src"
        continue
    }

    # Ensure parent dir exists (e.g., %LOCALAPPDATA% always does, but be safe).
    $parent = Split-Path $dst -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Backup-IfReal $dst

    New-Item -ItemType SymbolicLink -Path $dst -Target $src | Out-Null
    Write-Host "  linked $dst -> $src"
}

Write-Host ""
Write-Host "Done."
if ($backedUp) {
    Write-Host "Existing files were moved to: $backupDir"
}
Write-Host "Note: zsh package skipped on Windows. Use pwsh 7 instead — its profile is now linked."
Write-Host "Set wezterm to launch pwsh by default by editing wezterm if needed."
