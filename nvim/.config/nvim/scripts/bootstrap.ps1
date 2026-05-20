# Bootstrap script for this nvim config on Windows.
# Installs system dependencies required by the plugins in init.lua.
# Safe to re-run; skips anything already installed.
#
# Usage (in PowerShell):
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\bootstrap.ps1

$ErrorActionPreference = 'Stop'

function Log($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "!! $msg"  -ForegroundColor Yellow }
function Have($cmd) { $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue) }

if (-not (Have 'winget')) {
  Warn 'winget not found. Install "App Installer" from the Microsoft Store, then re-run.'
  exit 1
}

# winget package IDs. `--silent` suppresses prompts; `--accept-*` skips agreements.
$packages = @(
  'Neovim.Neovim',
  'BurntSushi.ripgrep.MSVC',
  'sharkdp.fd',
  'Git.Git',
  'OpenJS.NodeJS.LTS',
  'Rustlang.Rustup',
  'Python.Python.3.12'
)

foreach ($pkg in $packages) {
  Log "Installing $pkg (skipped if present)"
  winget install --id $pkg --silent --accept-package-agreements --accept-source-agreements 2>&1 |
    Where-Object { $_ -notmatch 'already installed' } | Out-Host
}

# Refresh PATH so rustup/cargo/etc. are visible in this session.
$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path', 'User')

# rustfmt + clippy are rust components, not Mason packages.
if (Have 'rustup') {
  Log 'Ensuring rustfmt and clippy are installed'
  rustup component add rustfmt clippy
} else {
  Warn 'rustup not on PATH yet. Open a new shell and run: rustup component add rustfmt clippy'
}

# Optional CLIs for the claudecode.nvim / kiro plugins.
if (-not (Have 'claude')) {
  Warn "Claude Code CLI ('claude') not found."
  Warn 'Install from: https://docs.claude.com/en/docs/claude-code'
}
if (-not (Have 'kiro')) {
  Warn "Kiro CLI ('kiro') not found."
  Warn 'Install from: https://kiro.dev'
}

Log 'Running :checkhealth headlessly as a smoke test'
if (Have 'nvim') {
  & nvim --headless -c 'checkhealth' -c 'qa' 2>&1 | Select-Object -Last 20
}

Log 'Done. Launch nvim - Lazy will install plugins, Mason will install LSPs/formatters on first run.'
