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

# Pairs of (repo-relative source, absolute destination).
$home_path = $HOME
$nvim_dest = Join-Path $env:LOCALAPPDATA 'nvim'

$links = @(
    @{ Src = (Join-Path $repo 'wezterm\.wezterm.lua');  Dst = (Join-Path $home_path '.wezterm.lua') },
    @{ Src = (Join-Path $repo 'git\.gitconfig');        Dst = (Join-Path $home_path '.gitconfig') },
    @{ Src = (Join-Path $repo 'nvim\.config\nvim');     Dst = $nvim_dest }
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
Write-Host "Note: zsh package skipped on Windows."
