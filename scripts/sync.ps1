# thin wrapper — all the logic lives in sync.mjs so there is one implementation
# to keep correct instead of one per platform.
#
#   .\scripts\sync.ps1 status          what differs, changes nothing
#   .\scripts\sync.ps1 push            repo -> ~\.claude
#   .\scripts\sync.ps1 pull            ~\.claude -> repo
#   .\scripts\sync.ps1 push --git      git pull first, then push
#   .\scripts\sync.ps1 push --dry-run  print the plan, write nothing

$ErrorActionPreference = "Stop"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Host "✗ node not found — required to run sync" -ForegroundColor Red
  Write-Host "  claude code installs via npm, so node is usually already present"
  Write-Host "  otherwise: https://nodejs.org"
  exit 1
}

node (Join-Path $PSScriptRoot "sync.mjs") @args
exit $LASTEXITCODE
